# Known Behaviours, Quirks & Gotchas

> Scope: a single triage list of every non-obvious behaviour, bug, and sharp edge the module docs
> flag with ⚠️, gathered here so a reviewer or on-call engineer can scan them in one place. Each row
> links to the doc with the full context. **These describe the code as it is today** — some are
> deliberate, some are latent bugs. None are fixed by writing them down; treat this as a backlog
> seed, not a changelog.
>
> When you fix one, update the source doc's ⚠️ note **and** this row (or remove it).

Severity is a documentation judgement, not a formal triage:
🔴 can corrupt data / leak access / crash · 🟠 wrong result or confusing behaviour · 🟡 cosmetic / minor.

---

## Security & access

| Sev | Behaviour | Detail |
|---|---|---|
| 🔴 | **Module permissions are not enforced server-side** on most endpoints — only `[Authorize]` (authenticated). A user without `CAG_RIDER.EDIT` is blocked in the UI but can still call `PUT /api/rider/{id}` directly. | [cross-cutting](authentication-authorization.md) |
| 🔴 | **Default rider password is derivable** — `"<FirstInitial>Welcome3!"`, identical scheme for every rider, no forced reset on first login. | [rider-onboarding](hr-workflow-onboarding.md) |
| 🔴 | **`GET /api/document/all` ignores company scoping** — returns every entity of a source regardless of the caller's `CompanyIds`. Every other list endpoint is scoped. | [document-expiry](document-management.md) |
| 🟠 | **Rider company reassignment skips scope checks** — `PUT /api/rider/{id}/company` doesn't verify the target company is in the caller's scope (unlike `AddVehicle`, which does). | [rider-management](rider-management.md) |
| 🟠 | **Vehicle update skips scope re-check** — `PUT /api/vehicle/update` can move a vehicle to another company via a changed `CompanyId`. | [vehicle-management](vehicle-management.md) |
| 🟠 | **Credentials committed in plaintext** in `appsettings.*.json` (DB + FTP). | [architecture-overview](architecture-overview.md) |
| 🟡 | **`cachedToken` never clears** on the UI — a refreshed session keeps sending the old bearer token until a full page reload. | [ui-data-layer](frontend-application-shell.md) |

## Error handling & status codes

| Sev | Behaviour | Detail |
|---|---|---|
| 🔴 | **Plain service exceptions → HTTP 500.** `NotFoundException` / `ValidationException` / `BusinessRuleException` are not `AdminAPIException`, so ~44 throws (validation, not-found) surface as **500 `InternalServerError`**, not 400/404. | [cross-cutting](authentication-authorization.md) |
| 🟠 | **`ApiBaseController.BadRequest/UnAuthorized` return HTTP 200** with the status only in the body (`{statusCode: 400, error}`). The UI must inspect the payload, not the HTTP status. | [cross-cutting](authentication-authorization.md) |
| 🟠 | **Malformed-JWT errors bypass the exception handler** — `AuthenticationMiddleware` runs before `ExceptionHandlingMiddleware`, so a decode failure is an unhandled 500, not a 401. | [architecture-overview](architecture-overview.md) |
| 🟠 | **Duplicate-vehicle-number on create returns 200**, not 409 — the exception is built with `statusCode: OK`. The update path correctly returns 400 for the same condition. | [vehicle-management](vehicle-management.md) |
| 🟠 | **Unhandled exceptions leak `error.Message`** verbatim in the response body. | [cross-cutting](authentication-authorization.md) |
| 🟡 | **200-with-error-body reads as success** to axios/`unwrap` — resolves with `data` undefined rather than rejecting. | [ui-data-layer](frontend-application-shell.md) |

## Data integrity (non-transactional / drift)

| Sev | Behaviour | Detail |
|---|---|---|
| 🔴 | **FTP + DB are never transactional.** Document/image rows and their files can diverge in either direction; no reconciliation job. | [document-upload](document-management.md) |
| 🔴 | **Rider delete is a hard delete, not transactional, and orphans the login.** Workflow rows can be gone while the rider delete fails; the auto-created `User` row is never removed. | [rider-onboarding](hr-workflow-onboarding.md) |
| 🟠 | **Vehicle assignment `IsAssigned` flag can drift** from the `RiderVehicleConfig` mapping — the pair isn't wrapped in a transaction. | [rider-vehicle-assignment](rider-management.md) |
| 🟠 | **Vehicle delete destroys assignment history** (hard-deletes the active mapping) while status-based release preserves it — inconsistent, and historical rows point at a now-missing vehicle. | [rider-vehicle-assignment](rider-management.md) |
| 🟠 | **Property stock arithmetic is inverted / unguarded** — issuing *increases* `TotalQuantity`, availability checks are commented out, counts can go negative. | [rider-management](rider-management.md) |
| 🟠 | **All deletes are hard deletes** regardless of an `IsActive` column. | [data-access](database-access-layer.md) |

## Surprising side effects

| Sev | Behaviour | Detail |
|---|---|---|
| 🔴 | **Listing riders performs writes.** `GET /api/rider/all` and `/paged` bulk-update rider statuses from leave data before returning — non-idempotent GETs, unsafe on a read replica. | [rider-management](rider-management.md) |
| 🟠 | **Rider status exit auto-unassigns the vehicle** — `FreeId`/`Suspended`/`Terminated`/`Cancelled` release the vehicle via both `ChangeRiderStatus` and `UpdateRiderAsync`. (Intended, but easy to miss.) | [rider-vehicle-assignment](rider-management.md) |
| 🟠 | **Rider detail is blocked mid-workflow** — `Onboarding`/`VisaProcess`/`LocalTransfer` return 403 unless `skipStatusCheck=true`. A freshly created rider "disappears" until the workflow finishes. | [rider-onboarding](hr-workflow-onboarding.md) |

## Correctness bugs (wrong result)

| Sev | Behaviour | Detail |
|---|---|---|
| 🟠 | **Vehicle image cache eviction uses the wrong key** — evicts `vehicleImage-{id}` but reads/writes `CacheKeys.Vehicle + id`, so deleted images keep serving from cache up to 30 min. | [vehicle-images](vehicle-management.md) |
| 🟠 | **Document delete returns `false` (reported as an error) on success** unless it was the last document of its type — and then skips cache eviction too. | [document-upload](document-management.md) |
| 🟠 | **Expiry can be edited but never added** via `PUT /api/document/expiry-date` (`AddIfnotfound: false`) — returns 0 → reported as an error. | [document-expiry](document-management.md) |
| 🟠 | **Expiry update writes `CreatedBy` instead of `UpdatedBy`** — audit lands in the wrong column, overwriting the creator. | [document-expiry](document-management.md) |
| 🟠 | **Vehicle image partial upload is silent** — a failed file is skipped with `continue`; only an all-fail batch reports an error. | [vehicle-images](vehicle-management.md) |
| 🟠 | **Reflection-based rider update can't clear a field** — null means "don't touch", so no column can be set back to NULL through `PUT /api/rider/{id}`. | [rider-management](rider-management.md) |
| 🟠 | **Rider expense PUT is a full replace** — omitted fields are written as 0, not preserved. | [rider-management](rider-management.md) |
| 🟠 | **`["documenttypes"]` query key ignores its argument** — switching header codes can serve a stale type list. | [ui-data-layer](frontend-application-shell.md) |
| 🟡 | **`"Firstname 0"` owner name** — `(ownerLastName || +"")` coerces `""` to `0`. | [partner-company](partner-company-management.md) |
| 🟡 | **Company-logo mutation callbacks reference `resetLogo` without calling it** — invalidation relies on the hook instead. | [partner-company](partner-company-management.md) |
| 🟡 | **Vehicle detail error message says "riders"** on a vehicle endpoint (copy-paste). | [vehicle-management](vehicle-management.md) |

## Crash risks

| Sev | Behaviour | Detail |
|---|---|---|
| 🟠 | **`rider.RiderName[0]` throws on empty name** — the validator checks mobile but not that the name is non-empty. | [rider-onboarding](hr-workflow-onboarding.md) |
| 🟠 | **Vehicle release NRE** — `UpdateVehicleAsync` dereferences a null active mapping before the friendly "not found" check, throwing 500. | [rider-vehicle-assignment](rider-management.md) |
| 🟡 | **Document uploader expiry-copy has no null guard** — `groupedData[code].filter(...)[0].expiryDate` throws if no existing doc of that type carries an expiry. | [document-upload](document-management.md) |

## Config & environment

| Sev | Behaviour | Detail |
|---|---|---|
| 🔴 | **`appsettings.{Environment}.json` casing matters on Linux** — `appsettings.Development.json` (capital D). Lowercase is silently ignored, leaving DB/JWT/FTP config unset. | [architecture-overview](architecture-overview.md) |
| 🟠 | **Migrations are applied by hand** — no framework; `Database/Migrations/*.sql` must be run manually and reference DDL re-exported. | [data-model](database-access-layer.md) |
| 🟠 | **FK collation is load-bearing** — business-id FKs must be `varchar(20) COLLATE utf8mb4_general_ci` or MySQL throws errno 150. | [data-model](database-access-layer.md) |
| 🟡 | **Two expense concepts coexist** — the flat `Rider.*` columns (`int`) and the new `RiderExpense` ledger (`DECIMAL`), pending backfill + cutover. | [data-model](database-access-layer.md) |
| 🟡 | **Hardcoded document type id `29` (Civil ID)** in the onboarding wizard — reseeding `DocumentType` mislabels documents. | [rider-onboarding](hr-workflow-onboarding.md) |

## Modelling / naming traps

| Sev | Behaviour | Detail |
|---|---|---|
| 🟠 | **Reflection SQL uses property names as column names** — renaming a C# property silently retargets the column, no compile-time link. | [data-access](database-access-layer.md) |
| 🟠 | **Anonymous update objects bypass the `CreatedAt/By` guard** — they write exactly the properties given. | [data-access](database-access-layer.md) |
| 🟡 | **`Company.Idx` vs `Company.CompanyId`** — the rider export selects `c.idx AS CompanyId`; different columns. | [data-model](database-access-layer.md) |
| 🟡 | **Grid state is localStorage, not URL** — not shareable, not restored by back/forward; page number not persisted. | [ui-data-layer](frontend-application-shell.md) |
| 🟡 | **`RiderExpenseController` route casing** and similar minor route-name inconsistencies across controllers. | [modules/README](implementation-impact-analysis.md) |

---

## How to use this list

- **Reviewing a PR** in one of these areas? Check whether it fixes, worsens, or is blind to the
  relevant row.
- **Fixing one?** Update the linked doc's ⚠️ note and this row together (keep docs and code in sync,
  per [CLAUDE.md](../CLAUDE.md)).
- **Triaging?** The 🔴 rows under *Security* and *Data integrity* are the ones most worth scheduling.
