# Performance audit — October 2026

Measured and fixed on 2026-10-27, branch `feature/phase2_requirements` (not on QA or PROD yet). Follows the PROD slowness investigation of 2026-10-26 (FTP connection pool, safe file names, DB pool settings, sales-cash fallback — same branch).

## 1. How the system spends time

```
Browser (Gulf) ──HTTPS──► Coolify server, Helsinki: Next.js UI + .NET 10 API
                                 │   every SQL statement: one ~0.26 s round trip
                                 ├──► MariaDB 10.11, GoDaddy shared hosting, Phoenix (US)  — 30 connections for Prod+QA+Dev
                                 └──► FTP(S), GoDaddy shared hosting                      — ~0.27 s per command, ~2.5 s per 200 KB transfer
```

- API: 34 controllers → 48 services → 63 Dapper repositories (≈36k lines). One connection per repository call (`IDbConnectionFactory.Create()`), pooled by MySqlConnector. No background workers or timers in the API.
- UI: Next.js 16 / TanStack Query (≈77k lines). One background job runs **in the browser**: `VacationStatusSync` POSTs `rider/vacation-status/sync` every 5 min from every open tab.
- The database work itself is cheap (the vehicle picker's joins run in a ~0.25 s round trip when only counting). What costs time is **round trips** and **bytes over the transatlantic link**.

## 2. Method

- The real API was run locally against the **Dev** database (same Phoenix host; the round trip from here, ~0.29 s, is close to Helsinki's 0.19–0.42 s). A .NET startup hook (no code change) recorded per request: total time, SQL statements, time in SQL, connection opens and time in opens, and every statement's text.
- Three builds, same Dev data: **main** (PROD code, b44e941), **branch HEAD** (0c9264f, before this pass) and the **working tree** (this pass).
- `bench.js` replays 70 read endpoints the screens call, plus three screen loads fired in parallel like the browser (rider page, rider list, home dashboard); medians of 5 rounds. `snapshot.js` saves 79 JSON responses per build and compares them (ignoring random trace ids and "now" timestamps, and reporting pure order changes separately).
- FTP and upload paths were measured with harnesses on the Dev FTP folder (200 KB files), against both main's and the branch's `FileService`.
- PROD was only read (row counts, routine definitions, `EXPLAIN`-free counts, FTP existence checks). Nothing was written there.

## 3. Bottlenecks found (ranked by measured impact)

| # | Finding | Evidence | Impact |
|---|---|---|---|
| 1 | **Every query paid two round trips.** MySqlConnector resets each connection taken from the pool (`ConnectionReset=true` default): a full round trip before every statement. | Pooled open 260 ms with reset, 0 ms without (OpenBench). main: 709 statements → 709 reset round trips, 217 s of 476 s DB time. | ~50% of all DB time, every screen |
| 2 | **Uploads opened a new FTP connection per file** (`AutoConnect`, ~7.7 s), one file at a time, and checked / created the folder every time (~1.7 s). | main: 5 files 44.5 s, 1 file 7.4 s, 1 download 7.4 s. | Client complaint "delayed uploads" |
| 3 | **Vehicle picker list transferred 3.3 MB** — every column of five joined tables plus a `Document` join the code never read (it doubles the rows). | 10.1 s from the Gulf, 4.4–5.0 s from the API; same joins with `COUNT(*)`: 0.25 s. | Rider Vehicle tab, Car EMI, company tabs |
| 4 | **No HTTP compression.** Picker lists are 0.2–1.4 MB of JSON. | `rider/all` 1.41 MB, `salescashentry/get` 830 KB, `vehicle/getall` 721 KB. | Every big list, over the browser's link |
| 5 | **Sequential round trips that didn't need to be:** paged lists (count, then keys), payroll list (summary before the three lists; category and order passes one after the other), expense ledger (loads the whole rider — 2 round trips, 7 statements — only to check access). | Hook: rider/paged 3 statements in series; payroll/all 7. | Rider/Vehicle/Company lists, payroll, rider page |
| 6 | **Client polling.** `useGetAllUsers` refetched every 5 s on the Users **and Cash Collection** pages; the first vacation sync refetched all rider queries on every app load even when it moved nobody. | ~720 `GET api/user` per hour per open page (~1 s DB each); rider page loaded twice after login. | Connection pressure (30-connection limit) |
| 7 | Login verified the BCrypt hash twice. | 263 ms CPU per verify (work factor 12). | Login |

Not bottlenecks (checked): the dashboard overview already runs its six counts in parallel; the vacation sync's update already skips unchanged riders; missing `DocumentTypeExpiry (source, sourceId)` index causes a full scan, but at ~5k rows it costs nothing measurable today.

## 4. Changes

API (`CAG.Admin.API`):

| File | Change |
|---|---|
| `DBRepository/Connection/SqlConnectionFactory .cs` | `ConnectionReset` off by default (`Database:ConnectionReset` / connection string override). Safe here: no user variables (`AllowUserVariables` off), temp tables, `SET SESSION` or locks; procedure variables are assigned before use; an abandoned transaction is still rolled back on return to the pool (verified). |
| `DBRepository/Utility/PagingQueryHelper.cs` | Count + page keys in one batch. |
| `DBRepository/Repository/VehicleRepository.cs` | `GetAllVehicleAsync`: only the mapped columns, no `Document` join. |
| `DBRepository/Repository/PayrollRepository.cs` | Summary in parallel with the lists; category and order passes in parallel (`EnrichAsync`); rider path no longer runs the unused summary query. |
| `DBRepository/Repository/RiderRepository.cs`, `Application/InfraInterface/IRiderRepository.cs` | `IsRiderAccessibleAsync` (one `SELECT EXISTS`, same filter as `GetRiderByIdAsync`). |
| `Application/Service/Implementation/RiderExpenseService.cs`, `RiderService.cs` | Ledger, active vehicles and delete use the light access check. |
| `Application/Service/Implementation/DocumentService.cs` | Files of one upload go to FTP together; all-or-nothing on the file server; unique timestamps; DB steps unchanged and in order. |
| `Application/Service/Implementation/FileService.cs` | Known-folder cache for uploads, retry with folder creation on 550. |
| `Application/Service/Implementation/UserService.cs` | Second BCrypt verification removed. |
| `API/Program.cs` | Brotli / gzip response compression for text and JSON (`ResponseCompression:Enabled`). |

UI (`CAG.Admin.UI`): `hooks/react-query/users.tsx` (no 5-second polling), `components/background/vacation-status-sync.tsx` (first refresh only when the sync moved riders).

## 5. Results (Dev database, medians of 5 rounds, 2026-10-27 19:33–19:39 UTC)

| Screen / operation | main (PROD code) | Branch | |
|---|---|---|---|
| Open rider page (8 calls in parallel) | 1,594 ms | 591 ms | 2.7× |
| Open rider list (6 calls) | 1,589 ms | 618 ms | 2.6× |
| Open home dashboard (7 calls) | 1,863 ms | 831 ms | 2.2× |
| All 70 read endpoints (sum of medians) | 60.1 s | 31.3 s | −48% |
| `vehicle/getall` | 4,869 ms | 1,223 ms | |
| `payroll/all` (one company, one month) | 2,937 ms | 1,099 ms | |
| `rider/paged` (20 rows) | 1,559 ms | 619 ms | |
| Upload 5 × 200 KB documents (one request) | 44.5 s | 6.0 s (16 s on the first request after a restart) | |
| Upload 1 document | 7.4 s | 2.7 s | |
| Open / download 1 document | 7.4 s | 2.8 s | |
| `rider/all` over the wire (Brotli) | 1.41 MB | 119 KB | |

The branch HEAD before this pass performed like main (1.65 s / 1.79 s / 2.40 s for the three screens), so the screen gains above come from this pass. Single statements that pull large results (e.g. `salescashentry/get`, 830 KB) vary 0.5–3.3 s on **both** builds with the shared server's load.

## 6. Tests run

- **Response equality**: 79 responses, branch HEAD vs working tree — 72 identical, 7 differing only in random trace ids / "now" timestamps or in row order that is already random on main (three lists without a full `ORDER BY`), **0 real differences** (includes `vehicle/getall`, three payroll lists, paged lists on several pages / sorts / search, the ledger for a valid and an unknown rider). main vs branch differs only where the requirements on this branch intend it (`cashCollection` permission column; rider properties no longer listed twice).
- **Connection reset**: abandoned transaction rolled back on reuse (same session, `@@in_transaction = 0`); stored procedures and inline SQL audited for session state.
- **Uploads (Dev, real `DocumentService`)**: 5 files incl. 3 with the same name — 5 rows in order, 5 distinct paths, each file holds its own content; a failing file — original error raised, no rows, the other files removed again; test rows and files cleaned up.
- **FTP**: 18 checks (round trip, parallel reads, missing files, legacy dotted names, traversal refused, 3 stored PROD files found read-only); known-folder cache — new folder, existing folder, folder deleted meanwhile (retried), content intact.
- **Login**: correct password → token; wrong password and unknown email refused with the same message as before.
- **Compression**: plain without `Accept-Encoding`, `br` / `gzip` with it, decompressed bodies match; Excel export not compressed.
- **Builds**: API builds (only existing nullability warnings); UI `tsc --noEmit` and eslint clean on the changed files.
- **Not tested**: the UI changes in a browser (the test login could not be entered there); the payroll list as a rider-linked user; uploads larger than 200 KB; any of this on QA or PROD.

## 7. Remaining bottlenecks and risks

1. **Location of the database and files (largest).** Every statement still costs ~0.26 s and every FTP command ~0.27 s. Moving MariaDB next to the API (and files to local disk / object storage) takes these to < 1 ms; see the infrastructure plan.
2. **Picker endpoints return whole tables** — `rider/all` (8 screens), `client-user-id/all`, `salescashentry/get` without a date range. Compression hides most of the transfer to the browser, not the transfer from the database. A server-side search endpoint for the pickers needs UI work.
3. **Vacation sync runs in browsers** — every open tab, every 5 min. A small hosted service in the API would run it once.
4. **First upload after an API restart** opens the FTP pool (~8 s). A warm-up at start-up would hide it.
5. **Indexes** — `DocumentTypeExpiry (source, sourceId)` has none (full scan per vehicle); harmless at today's size. Schema change, not made: needs approval and a migration script.
6. **Unordered lists** — `document/all`, `dashboard/documents/expiring`, `vehicle/expiry-alerts` return ties in random order (rows can swap between refreshes).
7. Risk notes for release: `ConnectionReset` off relies on the code keeping no session state — a future `SET @var` / temp table needs `Database:ConnectionReset=true` or its own cleanup. The pool cap (15) makes requests wait instead of failing when busy.
