# CAG Admin Platform — Architecture Reference

**Scope:** `c:\Repos\CAG` — the CAG Admin API, Admin UI, and MySQL schema snapshot.
**Compiled:** 2026-09-04, from direct inspection of the source at that date.
**Status of this document:** descriptive, not prescriptive. It records what the code does today, including defects. Where a claim is a judgement rather than an observation, it is marked as such.

---

## Table of contents

1. [System overview](#1-system-overview)
2. [Technology stack](#2-technology-stack)
3. [Service map](#3-service-map)
4. [Database architecture](#4-database-architecture)
5. [Elasticsearch architecture](#5-elasticsearch-architecture)
6. [API surface](#6-api-surface)
7. [Data flow diagrams](#7-data-flow-diagrams)
8. [Configuration and environment](#8-configuration-and-environment)
9. [Build and deploy pipeline](#9-build-and-deploy-pipeline)
10. [Known technical debt and observations](#10-known-technical-debt-and-observations)

---

## 1. System overview

CAG Admin is a **two-tier internal admin portal** for a rider/fleet operations business: riders, partner companies, vehicles, HR workflows, attendance, payroll, sales cash reconciliation, helpdesk ticketing, and passport requests.

It is deliberately small in moving parts: one API process, one web process, one relational database, and an FTP server used as a blob store. There is no service mesh, no message broker, no cache server, and no search cluster.

```
                              ┌──────────────────────────────┐
                              │          Browser             │
                              │  (admin staff, HR, finance)  │
                              └───────────────┬──────────────┘
                                              │ HTTPS
                                              ▼
        ┌──────────────────────────────────────────────────────────────┐
        │  CAG.Admin.UI — Next.js 15 (App Router, React 19)            │
        │                                                              │
        │   middleware.ts ── route-level permission gate               │
        │   NextAuth (Credentials, JWT session strategy)               │
        │   TanStack Query cache ── axios (Bearer interceptor)         │
        │                                                              │
        │   Node process, port 3000                                    │
        └───────────────────────────┬──────────────────────────────────┘
                                    │ HTTPS  /api/*   Authorization: Bearer <API JWT>
                                    ▼
        ┌──────────────────────────────────────────────────────────────┐
        │  CAG.Admin.API — ASP.NET Core 9 (Clean Architecture)         │
        │                                                              │
        │   Presentation   24 controllers, 167 endpoints               │
        │   Application    34 services, 41 repository interfaces       │
        │   Domain         46 DB models, API models, enums             │
        │   DBRepository   41 Dapper repositories                      │
        │                                                              │
        │   Kestrel, port 8080 (container) / 7130 (dev https)          │
        └───────┬───────────────────────────────────┬──────────────────┘
                │                                   │
                │ MySqlConnector + Dapper           │ FluentFTP (FTPS auto)
                ▼                                   ▼
   ┌─────────────────────────────┐      ┌──────────────────────────────┐
   │  MySQL                      │      │  FTP server                  │
   │  CAG_Admin_Dev / _PROD      │      │  documents, rider & vehicle  │
   │  52 tables, 2 procedures    │      │  images, helpdesk & passport │
   │  no views, no triggers      │      │  attachments, error logs     │
   └─────────────────────────────┘      └──────────────────────────────┘

   Plus: IMemoryCache — in-process, per-replica, used by 4 controllers only.
```

**Repository layout.** `c:\Repos\CAG` is a container folder, *not* a git repository. It holds two independent repositories and one untracked folder:

| Folder | Contents | Git |
|---|---|---|
| `CAG.Admin.API/` | .NET solution, 4 projects | own repo, branch `main` |
| `CAG.Admin.UI/` | Next.js application | own repo, branch `main` |
| `CAG.Admin.DB/` | MySQL schema dump + CSV catalog exports | untracked |

Commits are made separately in each repository; there is no root-level git and therefore no atomic cross-tier commit. A change that alters an API contract and its UI caller lands as two commits in two repositories with no shared identifier linking them.

---

## 2. Technology stack

### Backend — `CAG.Admin.API`

| Concern | Choice | Version |
|---|---|---|
| Runtime | .NET | 9.0 |
| Web framework | ASP.NET Core Web API | 9.0 |
| Data access | Dapper (no ORM) | 2.1.66 |
| DB driver | MySqlConnector | 2.5.0 |
| API docs | Scalar.AspNetCore + Microsoft.AspNetCore.OpenApi | 2.8.11 / 9.0.9 |
| Versioning | Asp.Versioning.Mvc | 8.1.0 |
| Auth | Microsoft.AspNetCore.Authentication.JwtBearer, System.IdentityModel.Tokens.Jwt | 9.0.9 / 8.14.0 |
| Password hashing | BCrypt.Net-Next | 4.0.3 |
| File transport | FluentFTP | 53.0.2 |
| Excel import/export | ClosedXML | 0.105.0 |

Vestigial references worth removing: `Microsoft.Data.SqlClient` 6.1.2 (API project) and `System.Data.SqlClient` 4.9.0 (DBRepository project), plus `using System.Data.SqlClient;` at the top of the connection factory. No SQL Server is used anywhere. `System.Collections` 4.3.0 is a redundant .NET Framework-era package reference.

### Frontend — `CAG.Admin.UI`

| Concern | Choice | Version |
|---|---|---|
| Framework | Next.js (App Router) | ^15.5.7 |
| UI runtime | React / React DOM | 19.1.0 |
| Language | TypeScript (`strict: true`) | ^5 |
| Server state | TanStack React Query | ^5.90.2 |
| HTTP | axios | ^1.12.2 |
| Auth | NextAuth | ^4.24.12 |
| Component library | Ant Design | ^6.0.0 |
| Styling | Tailwind CSS + PostCSS | ^4.1.16 |
| Data grid | AG Grid React | ^34.3.0 |
| Charts | Recharts, react-minimal-pie-chart | ^3.6.0 |
| Client state | Zustand | ^5.0.8 |
| Forms | react-hook-form | ^7.64.0 |
| Notifications | react-hot-toast | ^2.6.0 |
| Icons | Phosphor Icons, react-icons | ^2.1.10 |
| Misc | date-fns, html2pdf.js, jsonwebtoken, world-countries, react-phone-number-input | |

Zustand and TanStack Query coexist: Query owns all server state, Zustand covers the small amount of cross-component client state. `html2pdf.js` drives payslip export in the browser.

### Data tier

MySQL (InnoDB, `utf8mb4` and `latin1` mixed). No ORM, no migration tool, no connection pooler beyond the driver's built-in pool.

---

## 3. Service map

"Service" here means an application-layer class in `CAG.Admin.API.Application/Service/`, not a deployable unit. **The system deploys as exactly two processes.** All 34 services below run in-process inside the single API.

### Dependency direction

```
   CAG.Admin.API  (Presentation)
        │  references ──►  Application, Domain, DBRepository
        ▼
   CAG.Admin.API.Application  (services + InfraInterface contracts)
        │  references ──►  Domain
        ▼
   CAG.Admin.API.Domain  (models, enums, exceptions)
        ▲
        │  references
   CAG.Admin.API.DBRepository  ──► implements Application.InfraInterface
```

The dependency inversion is real: repository *interfaces* live in `Application/InfraInterface/`, implementations in `DBRepository/Repository/`. The Presentation project references DBRepository solely to register concrete types in DI.

### Registration lifetimes

| Component | Lifetime | Count |
|---|---|---|
| `IDbConnectionFactory` → `SqlConnectionFactory` | **Singleton** | 1 |
| `IAsyncFtpClient` → `AsyncFtpClient` | **Transient** | 1 |
| Application services | **Scoped** | 34 |
| Repositories | **Scoped** | 41 |
| `IMemoryCache` | Singleton (framework) | 1 |

All registrations are written by hand in [`Program.cs`](CAG.Admin.API/CAG.Admin.API/Program.cs) lines 77–155. There is no assembly scanning, so **adding a feature requires two manual `AddScoped` lines** — a routinely forgotten step that fails at request time with an unresolvable-dependency exception rather than at startup.

### Service catalog

| Service | Purpose | Key repository dependencies |
|---|---|---|
| `UserService` | Login, logout, user CRUD, password change, role assignment | `IUserRepository`, `IUserCompanyRepository`, `IRolePermissionRepository` |
| `TokenService` | JWT issuance (claims: UserId, Email, RoleId, RiderId, CompanyIds, ModulePermissions) | — |
| `CurrentUserService` | Reads `HttpContext.Items["CurrentUser"]` | — (uses `IHttpContextAccessor`) |
| `RolePermissionService` | Module-permission matrix read/update | `IRolePermissionRepository` |
| `RiderService` | Rider CRUD, status, company/client reassignment, expenses, Excel export | `IRiderRepository`, `IRiderStatusRepository`, `IRiderPropertyRepository`, `IIdSequenceRepository` |
| `RiderAssignmentService` | Rider↔vehicle and rider↔client assignment orchestration | `IRiderVehicleConfigRepository`, `IClientRiderConfigRepository` |
| `ClientRiderConfigService` | Client-rider contract windows (start/end dates) | `IClientRiderConfigRepository` |
| `ClientUserIdService` | External client user-ID mapping incl. temp riders | `IClientUserIdRepository` |
| `BankDetailsService` | Rider bank accounts (validated) | `IBankDetailsRepository` |
| `PartnerCompanyService` | Company CRUD, partners, company documents, logo | `ICompanyRepository`, `IPartnerRepository`, `ICompanyDocumentRepository` |
| `ClientService` | Client master data | `IClientRepository` |
| `VehicleService` | Vehicle CRUD, images metadata | `IVehicleRepository`, `IVehicleImageRepository` |
| `PropertyService` / `SimCardService` | Issued property (kit) and SIM inventory | `IPropertyRepository`, `IRiderPropertyRepository`, `ISimCardRepository` |
| `DocumentService` | Document upload/download/delete, metadata | `IDocumentRepository`, `IDocumentTypeRepository`, `IFileService` |
| `DocumentTypeExpiryService` | Per-document expiry tracking | `IDocumentTypeExpiryRepository` |
| `FileService` | FTP upload/get/delete/append — the only FTP toucher | `IAsyncFtpClient` |
| `HrWorkflowService` | Onboarding/offboarding task workflows (JSON task details) | `IHrWorkflowRepository` |
| `AttendanceService` | Attendance query + Excel import with per-row validation | `IAttendanceRepository`, `IAttendanceUploadLogRepository` |
| `LeaveRequestService` / `LeaveRequestCommentService` | Leave requests and their comment thread | `ILeaveRequestRepository`, `ILeaveRequestCommentRepository` |
| `PayrollService` | Payslip generation (delegates to stored procedure), summaries | `IPayrollRepository` |
| `CarEmiService` | Vehicle EMI schedules per rider | `ICarEmiRepository` |
| `OrderValueService` | Per-client/batch order pricing | `IOrderValueRepository`, `IBatchRepository` |
| `BatchService` / `BatchVehicleCategoryService` | Batch and vehicle-category reference data | `IBatchRepository`, `IBatchVehicleCategoryRepository` |
| `RiderOrderService` | Rider order entry + Excel import, upload logs | `IRiderOrderRepository`, `IRiderOrderUploadLogRepository`, `IOrderListRepository` |
| `SalesCashService` | Cash entry and reconciliation details, Excel import/export | `ISalesCashEntryRepository`, `ISalesCashDetailsRepository` |
| `DashboardService` | Aggregate KPIs, expiring compliance, finance rollups | many, read-only |
| `CompanyPerformanceService` / `RiderPerformanceService` | Monthly performance aggregates | `ICompanyPerformanceRepository`, `IRiderPerformanceRepository` |
| `HelpdeskService` | Ticketing (JSON comment threads) | `IHelpdeskRepository` |
| `PassportRequestService` | Passport request tickets | `IPassportRequestRepository` |
| `IdGeneratorService` | Human-readable IDs (e.g. `RD261011`) via `IdSequences` | `IIdSequenceRepository` |

### Frontend module map

The UI mirrors the API domain-by-domain in four parallel layers:

```
constants/api-urls.ts    →  http-client/*.api.ts  →  hooks/react-query/*.tsx  →  page components
  (1 file, all URLs)         (20 files)               (21 files)                  (route groups)
```

Supporting: `constants/grid-props/` (22 AG Grid column-definition builders), `components/grid/` (24 cell renderers), `models/admin-api-models/` (25 TypeScript response shapes), `enum/` (10 enum modules), `utils/` (9 helpers).

---

## 4. Database architecture

### 4.1 Connection configuration

Single logical connection, `ConnectionStrings:CAGDBConnection`, resolved in `SqlConnectionFactory` and registered **Singleton** — the factory is shared, but each call to `Create()` returns a fresh `MySqlConnection` that the caller disposes.

| Environment | Server | Database | TLS |
|---|---|---|---|
| Development | `50.62.221.135:3306` | `CAG_Admin_Dev` | `SslMode=none` |
| Production | `50.62.221.135:3306` | `CAG_Admin_PROD` | `SslMode=none` |

Dev and prod share a host and credentials, and both connect in cleartext to a public IP. See §10.

### 4.2 Access pattern — no ORM

```
Repository (41)
   └── GenericRepository<T>(IDbConnectionFactory factory, string table)
         ├── GetAllAsync / GetByAsync            reflection-built SELECT
         ├── AddAsync / UpdateAsync / DeleteAsync  reflection-built INSERT/UPDATE/DELETE
         ├── QueryAsync<TResult> / ExecuteAsync    hand-written SQL
         └── ExecuteProcedureAsync / QueryProcedureAsync / ExecuteScalarProcedureAsync
```

`DapperHelper` composes SQL by reflecting over **property names**, which are assumed to equal column names:

- `[Key]`-decorated properties are excluded from INSERT and UPDATE column lists.
- `CreatedAt` and `CreatedBy` are never included in an UPDATE (hardcoded not-updatable set).
- `createdAt`/`updatedAt` are stamped automatically with `DateTime.UtcNow` on insert; `updatedAt` on update.
- `BuildWhere` joins conditions with `AND` only — no `OR`, no operators other than equality.

The table name is a **constructor string literal**, in one of three syntactic forms across the codebase (inline primary constructor, wrapped primary constructor, classic `: base(factory, "X")`). Consequence: the entity↔table binding is invisible to static analysis and to IDE rename refactors.

Transactions: `AddAsync`, `UpdateAsync`, and `DeleteAsync` have overloads taking an explicit `IDbConnection` + `IDbTransaction` for multi-table writes, and deliberately do not dispose a connection they did not create.

### 4.3 Entity ↔ table coverage

46 classes in `Domain/Model/DBModels/` against **52 live tables**.

Six tables have **no C# model** and are reached only through hand-written SQL or stored procedures:

```
PayrollEarnings   PayrollExpenses   PayrollVehicleEMI   Permission   Task   TaskStatus
```

Two naming mismatches, both harmless because the table name is passed explicitly but both a trap for search-based navigation:

```
class IdSequence        →  table IdSequences
class RiderOrderDBModel →  table RiderOrder
```

### 4.4 Schema diagram (text)

`Rider` is the hub of the model — 14 of 44 foreign keys point at it. `Company` is second with 7.

```
                        ┌──────────┐             ┌──────────┐
                        │  Role    │             │  Client  │
                        └────┬─────┘             └────┬─────┘
                             │ roleId                 │ clientId
                        ┌────▼─────┐                  │
              riderId   │   User   │◄────┐            │
        ┌──────────────►└────┬─────┘     │            │
        │                    │ userId    │            │
        │               ┌────▼────────┐  │            │
        │               │ UserCompany │──┼────┐       │
        │               └─────────────┘  │    │       │
        │                                │    │       │
        │                          ┌─────┴────▼───┐   │
        │                          │   Company    │◄──┼────────┐
        │                          └──┬───┬───┬───┘   │        │
        │                             │   │   │       │        │
        │            ┌────────────────┘   │   └───────┼──┐     │
        │            │                    │           │  │     │
        │   ┌────────▼────────┐  ┌────────▼──────┐    │  │     │
        │   │ CompanyDocument │  │    Partner    │    │  │     │
        │   └─────────────────┘  └───────────────┘    │  │     │
        │                                             │  │     │
        │   ┌──────────────────┐  ┌─────────────────┐ │  │     │
        │   │ CompanyPerform.  │  │ CompanyPayroll  │ │  │     │
        │   └──────────────────┘  │    Summary      │ │  │     │
        │                         └─────────────────┘ │  │     │
        │                                             │  │     │
   ┌────┴──────────────────────────────────────┐      │  │     │
   │                  Rider                    │◄─────┘  │     │
   │  riderId (varchar PK, e.g. RD261011)      │         │     │
   │  companyId FK, statusId FK                │         │     │
   └─┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬─────┘         │     │
     │  │  │  │  │  │  │  │  │  │  │  │  │               │     │
     │  │  │  │  │  │  │  │  │  │  │  │  └─► RiderStatus (parent)
     │  │  │  │  │  │  │  │  │  │  │  └────► SimCard.assignedTo   [SET NULL]
     │  │  │  │  │  │  │  │  │  │  └───────► ClientUserId.tempRiderId [SET NULL] ──► Client
     │  │  │  │  │  │  │  │  │  └──────────► ClientRiderConfig
     │  │  │  │  │  │  │  │  └─────────────► RiderVehicleConfig ──► Vehicle ──► VehicleImage
     │  │  │  │  │  │  │  └────────────────► RiderProperty ──► Property   [CASCADE]
     │  │  │  │  │  │  └───────────────────► RiderPerformance
     │  │  │  │  │  └──────────────────────► SalesCashEntry ──► Client, Company
     │  │  │  │  └─────────────────────────► SalesCashDetails ──► Client, Company
     │  │  │  └────────────────────────────► RiderOrder ──► BatchVehicleCategory
     │  │  └───────────────────────────────► OrderList        (115k rows — largest table)
     │  └──────────────────────────────────► LeaveRequest ──► LeaveRequestComment
     └─────────────────────────────────────► Attendance
                                             HrWorkflow ──► Task, TaskStatus

   Payroll ──┬─► PayrollEarnings     [CASCADE]      Helpdesk ──────► TicketType
             ├─► PayrollExpenses     [CASCADE]      PassportRequest ► TicketType
             └─► PayrollVehicleEMI   [CASCADE]      OrderValue ──► Client, Batch [CASCADE]

   Unlinked reference tables: PageModule, Permission, RolePermission, DocumentType,
   DocumentTypeExpiry, Document, IdSequences, PayrollErrorLog,
   AttendanceUploadLog, RiderOrderUploadLog, CarEmi
```

### 4.5 Entity relationships

**44 foreign keys.** Delete-rule policy is predominantly `RESTRICT`, with deliberate exceptions:

| Rule | Relationships | Rationale (inferred) |
|---|---|---|
| `CASCADE` delete | `Payroll` → its 3 child tables; `Batch` → `OrderValue`; `Property` → `RiderProperty`; `User`/`Company` → `UserCompany`; `Rider` → `User` | child rows are meaningless without the parent |
| `SET NULL` | `ClientUserId.tempRiderId`, `SimCard.assignedTo` | soft assignment — the record survives unassignment |
| `RESTRICT` | everything else | protects operational history |

Note `Rider` → `User` cascades on delete: deleting a rider deletes the linked login account.

**22 unique constraints — these encode the import idempotency rules** and are the most important thing to know before touching bulk-import code:

| Table | Unique key | Guards |
|---|---|---|
| `OrderList` | `(riderId, orderDate)` | daily order import |
| `Attendance` | `(riderId, attendanceDate)` | attendance Excel import |
| `Payroll` | `(payMonth, riderId)` | one payslip per rider per month |
| `RiderOrder` | `(riderId, batchNo, orderMonth)` | rider-order Excel import |
| `SalesCashDetails` | `(riderId, entryDate)` | cash reconciliation import |
| `SalesCashEntry` | `(clientUserId, entryDate)` | cash entry |
| `CompanyPerformance` | `(companyId, performanceMonth)` | monthly aggregate |
| `CompanyPayrollSummary` | `(companyId, payMonth)` | monthly aggregate |
| `RiderPerformance` | `(clientId, riderId, performanceMonth)` | monthly aggregate |
| `CarEmi` | `(riderId, vehicleId)` | one active EMI per pairing |
| `RiderProperty` | `(riderId, propertyId)` | one issuance per kit item |
| `IdSequences` | `(entityType, yearPrefix)` | ID generator counter |
| `VehicleImage` | `(vehicleId, isDaftar)` | one registration doc per vehicle |
| Natural keys | `User.email`, `Company.code`, `Company.idx`, `Client.clientCode`, `Batch.batchNo`, `Property.propertyCode`, `Property.propertyName`, `ClientUserId.clientUserId`, `SimCard.mobileNumber` | |

Re-running an import collides on these rather than duplicating — but the collision surfaces as a driver exception mapped to HTTP 500, not a clean 409 (see §10).

**6 check constraints:**

```
ClientRiderConfig  CONSTRAINT_1   endDate IS NULL OR endDate >= startDate
Helpdesk           comments       json_valid(comments)     (declared twice)
HrWorkflow         taskDetails    json_valid(taskDetails)
PassportRequest    comments       json_valid(comments)     (declared twice)
```

JSON is stored in text columns with a validity guard rather than in native `JSON` columns — so JSON path queries and indexing are unavailable; these fields are read whole and parsed in C#/TypeScript.

### 4.6 Index strategy

Three tiers, in descending order of intentionality:

1. **Composite time-series indexes** — the only hand-tuned ones, all on high-volume operational tables:
   `Attendance.idx_rider_date`, `Attendance.idx_status_date`, `Attendance.idx_date`, `RiderOrder.idx_month_batch`, `RiderOrder.idx_order_month_rider`.
2. **Unique constraints doubling as indexes** — the 22 above. Most range queries in the reporting endpoints are served by these rather than by purpose-built indexes.
3. **Automatic FK indexes** — the majority; InnoDB creates one per foreign key.

**Gaps (judgement).** `OrderList`, at 115,573 rows and 6.5 MB — an order of magnitude larger than any other table — carries only its `uq_rider_date` unique index. Dashboard and payroll queries that filter by `companyId` or by date range without a leading `riderId` cannot use it and will table-scan. The `Rider` table's frequent `WHERE isActive = 1 AND companyId IN (...)` filter (the multi-tenant scope predicate on nearly every rider query) is served only by the single-column `fk_rider_company` index.

### 4.7 Migrations

**There is no migration framework.** No EF Core migrations, no Flyway, Liquibase, dbmate, or numbered SQL scripts; no schema-version table. `CAG.Admin.DB/` is a manually exported snapshot:

| File | Contents |
|---|---|
| `CAG_Schema.sql` | full DDL dump (dated Jun 21) |
| `Tables.csv`, `Columns.csv.csv` | table and column catalog (Sep 3–4) |
| `Primary_Keys.csv`, `Foreign_Keys.csv`, `Unique_Constraints.csv`, `Check_Constraints.csv`, `Indexes.csv` | constraint catalog |
| `Relationship_Summary.csv`, `CAG_Admin_Schema_Diagram.erd` | derived views |
| `Stored_Procedures.csv`, `Collations.csv`, `Tables_DDL.csv` | routine and encoding catalog |

**Observed drift:** the DDL dump contains **53** `CREATE TABLE` statements against **52** live tables — the extra is a leftover table named `temp`. The dump predates the CSV exports by ten weeks. Collations are split 30 `utf8mb4_general_ci` / 22 `latin1_swedish_ci`, the signature of tables added at different times; `latin1` tables will corrupt non-Latin text (rider names, Arabic addresses).

Schema changes reach production by hand-run DDL. Nothing in either repository records that a change happened, and nothing verifies that a deployed API build matches the schema it expects.

### 4.8 Stored procedures, views, functions

**2 procedures. 0 views. 0 triggers. 0 stored functions.**

```
sp_generate_company_payroll     ← PayrollRepository.cs:592, via QueryProcedureAsync
        │
        └── CALL sp_process_rider_payroll     ← invoked only from inside the above
```

This is the one place where business logic lives in the database. Payroll generation iterates companies and riders inside MySQL and writes `Payroll` plus the three `Payroll*` child tables (none of which have C# models) and `PayrollErrorLog`. Changing payroll rules may require editing a procedure that exists only on the server and in a CSV export — it is not in version control in executable form.

---

## 5. Elasticsearch architecture

**Not applicable — this system contains no Elasticsearch, OpenSearch, or any other search engine.**

This section is retained because it was requested, and is answered with the negative result rather than omitted, so that its absence is documented rather than ambiguous.

**Evidence.** A case-insensitive scan across every `.cs`, `.ts`, `.tsx`, `.json`, `.csproj`, `.sln`, `.sql`, `.mjs`, and `Dockerfile` in the workspace (excluding `node_modules`, `.next`, `obj`, `bin`, and lockfiles) for:

```
elasticsearch | opensearch | redis | mongo | postgres | npgsql | sqlite |
cassandra | dynamodb | kafka | rabbitmq | memcached | cosmos | neo4j | influx
```

returned **zero matches**. There is no `NEST`/`Elastic.Clients.Elasticsearch` package, no `@elastic/elasticsearch` dependency, no index template, no analyzer definition, no ILM policy, and no ingest pipeline.

**What performs the equivalent roles:**

| Elasticsearch role | Actual implementation here |
|---|---|
| Index catalog / mappings | MySQL tables + InnoDB indexes (§4.6) |
| Full-text / fuzzy search | SQL `WHERE`/`LIKE` in repositories; AG Grid client-side filtering over already-fetched rows |
| Aggregations | `DashboardService` — SQL `GROUP BY` against MySQL, computed per request |
| Read-model caching | `IMemoryCache`, in-process, 4 controllers (`Document`, `PartnerCompany`, `User`, `Vehicle`), image/document payloads only |
| Indexing pipeline | none — no denormalized read model exists |

**Implication (judgement).** Every list screen retrieves the full result set and filters in the browser: `useGetAllRiders` fetches all riders (1,778 rows joined across 8 tables) and AG Grid filters client-side. This is acceptable at current volumes and will degrade first on `OrderList` (115k rows). If search or large-list performance becomes a problem, the cheaper fix is server-side pagination plus targeted indexes, not introducing a search cluster.

---

## 6. API surface

### 6.1 Endpoint inventory

**167 endpoints across 24 controllers.** Every controller declares a literal `[Route("api/<name>")]`, which **overrides** the `[Route("[controller]")]` and `[Route("v{version:apiVersion}/[controller]")]` attributes inherited from `ApiBaseController`. API versioning is configured but inert — there is no `/v1/` prefix in practice, and the UI's base URL already ends in `/api/`.

| Base route | Count | Notable endpoints |
|---|---|---|
| `api/rider` | 23 | `GET all`, `GET all/with-company`, `GET {riderId}`, `PUT {riderId}/status`, `POST {riderId}/vehicle/{vehicleId}/{isAssign}`, `GET export`, `{riderId}/bank-details` ×4, `{riderId}/property` ×3, `{riderId}/performance` ×2 |
| `api/company` | 12 | company CRUD, `PUT partner`, `PUT {id}/documents`, `logo` upload/get/delete |
| `api/dashboard` | 12 | `overview`, `compliance/expiring`, `riders/breakdown`, `workforce`, `finance`, `finance/expense`, `finance/details/{traffic-fines,emi}`, `documents/expiring`, `vehicles/expiring`, `company/{orders,performance}` |
| `api/vehicle` | 10 | CRUD + `image/{upload,metadata,delete}` |
| `api/leaverequest` | 10 | request CRUD + `comment/*` ×4 |
| `api/riderorder` | 9 | `get`, `get-client-user-ids/{riderId}`, `POST`, permanent/temporary update, `import`, `getLogs`, `performance` |
| `api/property` | 9 | property CRUD + `simcards` ×4 |
| `api/user` | 8 | user CRUD, `updatepassword`, `image` ×3 |
| `api/document` | 7 | `types`, `get`, `upload`, `delete`, `expiry-date`, `all`, `{source}/{sourceId}` |
| `api/carEmi` | 7 | CRUD + `close/{id}` |
| `api/passport-request` | 6 | ticket CRUD + `ticket-types` |
| `api/helpdesk` | 6 | ticket CRUD + `ticket-types` |
| `api/hrworkflow` | 6 | `tasks/{processType}`, `generate`, `riders/all`, `workflows/{riderId}`, `workflow/{riderId}/active`, `task/update` |
| `api/ordervalue` | 6 | CRUD + `batch-vehiclecategory` |
| `api/client-user-id` | 6 | CRUD + `update-rider-assignment` |
| `api/client` | 5 | CRUD |
| `api/batch` | 5 | CRUD |
| `api/salescashentry` | 4 | `get`, `POST`, `PUT {id}`, `export` |
| `api/payroll` | 4 | `all`, `{id}`, `generate`, `summary` |
| `api/attendance` | 4 | `get`, `getlog`, `import`, `orderList/import` |
| `api/salescashdetails` | 3 | `get`, `import`, `PUT {id}` |
| `api/permissions` | 3 | `getall`, `getbyroleId`, `update` |
| `api/Auth` | 2 | `login`, `logout` — the only anonymous endpoints |
| `api/batch-vehicle-category` | **0** | dead controller: injects a service, declares no actions |

Route conventions are inconsistent: verb-suffixed (`vehicle/getall`, `batch/add`, `carEmi/delete/{id}`) coexists with REST-style (`api/client` POST/PUT/DELETE, `api/property`). `POST api/attendance/orderList/import` sits under the attendance controller but belongs to the rider-order domain.

### 6.2 Request/response contract

Every endpoint except file downloads returns:

```csharp
APIResponseModel { object? Data; HttpStatusCode StatusCode; object? Error }
```

built via `ApiBaseController` helpers: `Success(data)`, `SuccessWithNoData()`, `Conflict()`, `BadRequest(error)`, `UnAuthorized(error)`. File downloads (`document/get`, `rider/export`, `user/image`, `vehicle/image`, `company/logo/{id}`, `salescashentry/export`) return `IActionResult` with a `Content-Disposition` header — which is why CORS exposes that header explicitly.

The UI's `unwrap<T>()` helper reads `res.data.data`. **An endpoint returning a bare object instead of `Success(data)` silently yields `undefined` in the UI** — a failure mode with no error message on either side.

Errors are shaped by `ExceptionHandlingMiddleware` as `{ error, message, code }`, with `AdminAPIExceptions` mapped to status codes:

```
Unauthorized → 401   ValidationFailed → 400   InvalidRequest → 400
DuplicateEntityExists → 409   EntityNotFound → 404   Forbidden → 403   default → 500
```

Request DTOs live in `Domain/Model/APIModels/` (`*RequestModel`, `*ApiModel`, `*Dto`). Several endpoints bind **raw DB models** from the request body instead — `AddClient(Client)`, `AddRider(Rider)`, `UpdateVehicle(Vehicle)`, `UpdateTicket(int, Helpdesk)`, `AddSimCard(SimCard)`, `Add(Batch)` — exposing every column-backed property to mass assignment.

**Validation is minimal:** two hand-rolled static validators (`RiderValidator.Validate`, called once in `RiderService:141`; `BankDetailsValidator.Validate`, called twice) that throw `ValidationException`. There is no FluentValidation and essentially no DataAnnotations, so `[ApiController]`'s automatic 400 has nothing to evaluate. Most controllers do a bare `if (request == null) return BadRequest(...)`. In practice **the database's unique and check constraints are the primary validation layer**.

### 6.3 Middleware pipeline

```
UseHttpsRedirection
  └─ AuthenticationMiddleware        (custom — decode JWT → HttpContext.Items["CurrentUser"])
       └─ ExceptionHandlingMiddleware (custom — exception → JSON + FTP log)
            └─ UseCors
                 └─ UseAuthentication → UseAuthorization → MapControllers
```

There are **no MVC filters** of any kind — no `IActionFilter`, `IAsyncActionFilter`, result filter, or exception filter. All cross-cutting behavior is middleware. On the client side the only interceptor is the axios request interceptor that attaches the bearer token.

Two ordering defects follow from this arrangement; both are detailed in §10.

### 6.4 Authentication flow

```
 ┌────────┐  1. email + password        ┌──────────────┐
 │Browser │ ──────────────────────────► │  NextAuth    │
 └────────┘                             │ authorize()  │
                                        └──────┬───────┘
                                               │ 2. POST /api/Auth/Login
                                               ▼
                                        ┌──────────────┐
                                        │ UserService  │ BCrypt.Verify
                                        │ TokenService │ HS256 sign
                                        └──────┬───────┘
                        3. JWT { UserId, Email, RoleId, RiderId,
                                 CompanyIds, ModulePermissions, exp }
                                               │
                                               ▼
                                        ┌──────────────┐
                        4. jwt.verify(token, process.env.JWT_SECRET)
                                        │  NextAuth    │  ── decodes claims into session
                                        └──────┬───────┘
                        5. httpOnly cookie "next-auth.session-token"
                           session.access_token = <API JWT>
                                               │
 ┌────────┐  6. every request              ┌───▼──────────┐
 │Browser │ ─────────────────────────────► │ axios        │ Authorization: Bearer <API JWT>
 └────────┘                                └───┬──────────┘
                                               ▼
                                    ┌──────────────────────┐
                                    │ AuthenticationMware  │ ReadJwtToken — NO signature check
                                    │ UseAuthentication    │ full validation (iss/aud/exp/key)
                                    │ [Authorize]          │ requires authenticated user only
                                    └──────────────────────┘
```

**Critical coupling:** step 4 means the UI's `JWT_SECRET` must be byte-identical to the API's `AppSettings:Token`. The UI does not treat the API token as opaque — it verifies and decodes it locally. A rotation on either side alone breaks login with a signature error.

**Authorization model:**

| Layer | Enforcement |
|---|---|
| UI route | `middleware.ts` maps path → module code via `RolePageCode`, checks `session.modulepermissions` |
| UI component | `useHasPermission(module, permission)` hides/disables actions |
| API | `[Authorize]` on every controller except `AuthController` — **authentication only** |

Across the entire API there are **zero** `[Authorize(Roles=...)]`, **zero** `[Authorize(Policy=...)]`, no `AddAuthorization` policy configuration, and no fallback policy. The only `RoleId` comparisons anywhere are in `UserService` (excluding riders from user lists; deciding company assignment on create/update) — business rules, not access control.

Permission codes are `MODULE.PERMISSION` strings (13 modules × `VIEW`/`EDIT`/`DELETE`), carried as one comma-separated claim, defined in `enum/code-constants.ts` and stored in `Role`/`Permission`/`RolePermission`/`PageModule`.

### 6.5 Message queues and event-driven flows

**None.** No broker, no scheduler, no `IHostedService`/`BackgroundService`, no Hangfire or Quartz. Everything is synchronous request/response.

The single asynchronous path is `ExceptionHandlingMiddleware:78`:

```csharp
_ = Task.Run(() => fileService.AppendAsync(log));
```

Fire-and-forget on a **scoped** `IFileService` resolved from the request scope — the scope may be disposed while the FTP append is in flight, and any exception is discarded unobserved.

Bulk imports that would conventionally be queued (attendance, rider orders, sales cash) run **inline inside the HTTP request**, parsing whole workbooks and writing thousands of rows before responding.

---

## 7. Data flow diagrams

### 7.1 Read path — rider list

```
Browser  ──► useGetAllRiders()            queryKey ["rider","all"], TanStack cache
            └─► GetAllRidersAsync()        axios GET rider/all  (+ Bearer)
                └─► RiderController.GetAllRiders
                    └─► RiderService.GetAllRidersAsync
                        ├─► ICurrentUserService.GetCurrentUser() → CompanyIds
                        └─► RiderRepository.GetAllRidersAsync(companyIds)
                            └─► 8-table LEFT JOIN, Dapper multi-map into
                                Dictionary<string, RiderAPIResponse>
                                (Rider, RiderStatus, Company, RiderVehicleConfig,
                                 Vehicle, ClientUserId, Client, RiderProperty, Property)
                                WHERE r.isActive = 1
                                  AND (r.companyId IN @CompanyIds OR r.companyId IS NULL)
                        ◄── APIResponseModel { Data = [...] }
            ◄── unwrap → res.data.data → AG Grid (all rows, client-side filter/sort)
```

Note the `OR r.companyId IS NULL` clause: company-less riders are visible to every tenant.

### 7.2 Write path — Excel import (rider orders)

```
Browser  ──► multipart/form-data ──► POST api/riderorder/import
                └─► RiderOrderController.Import([FromForm] RiderOrderImportRequestModel)
                    └─► RiderOrderService
                        ├─► ClosedXML: open workbook, iterate rows
                        ├─► per-row validation
                        │     StringConstants.BuildEmptyCellError(col,row,val)
                        │     StringConstants.BuildInvalidStatusError(col,row,val)
                        ├─► RiderOrderRepository.AddAsync(...)   ← uq_rider_month_batch
                        └─► RiderOrderUploadLogRepository.AddAsync(log)
                    ◄── APIResponseModel (after the entire file is processed, synchronously)

  Parallel paths:  POST api/attendance/import        → Attendance + AttendanceUploadLog
                   POST api/attendance/orderList/import → OrderList
                   POST api/salescashdetails/import  → SalesCashDetails
```

### 7.3 Payroll generation — logic in the database

```
POST api/payroll/generate
  └─► PayrollController.Add(GeneratePayslipRequest)
      └─► PayrollService
          └─► PayrollRepository:592  QueryProcedureAsync("sp_generate_company_payroll")
              └─► MySQL: loop companies → riders
                     └─► CALL sp_process_rider_payroll
                            writes Payroll
                                  PayrollEarnings      (no C# model)
                                  PayrollExpenses      (no C# model)
                                  PayrollVehicleEMI    (no C# model)
                                  PayrollErrorLog
```

### 7.4 File upload — dual-store write

```
POST api/document/upload  [FromForm] FileUploadRequestModel
  └─► DocumentController
      └─► DocumentService
          ├─► FileService.UploadAsync(stream, FilePath:<category>)   ──► FTP server (bytes)
          └─► DocumentRepository.AddAsync(metadata)                  ──► MySQL (row)
```

The two writes are **not transactional**. An FTP success followed by a DB failure orphans the file; a DB success followed by an FTP failure leaves a metadata row pointing at nothing. Nothing reconciles the two stores.

### 7.5 Store ownership summary

| Store | Written by | Read by |
|---|---|---|
| MySQL | API only (41 repositories + 2 stored procedures) | API only |
| FTP | API only (`FileService`) | API (`FileService`), streamed to browser |
| `IMemoryCache` | API, 4 controllers | same process only |
| NextAuth cookie | UI (`next-auth.session-token`, httpOnly) | UI middleware + server components |
| TanStack Query cache | UI, per browser tab | UI components |

The UI holds **no database driver** and never reaches MySQL or FTP directly — every byte crosses the 167 HTTP endpoints.

---

## 8. Configuration and environment

### 8.1 API configuration

`appsettings.json` (shared), `appsettings.development.json`, `appsettings.production.json`:

| Section | Purpose |
|---|---|
| `ConnectionStrings:CAGDBConnection` | MySQL connection string |
| `AppSettings:Token` | JWT signing key (HS256) — **must equal UI `JWT_SECRET`** |
| `AppSettings:Issuer` | `CAG.Admin.API` |
| `AppSettings:Audience` | `CAG.Admin.UI` |
| `FTPSettings:Host/UserName/Password/Post` | FTP credentials (note the `Post` typo for `Port`; the value is unused — `AsyncFtpClient` is constructed with host/user/password only) |
| `FilePath:CompanyFiles` | `CAG_Admin/QA/Company` — **points at QA in the Development file while its siblings point at Dev** |
| `FilePath:{UserFiles,VehicleFiles,RiderFiles,LogPath,HelpdeskFiles,PassportRequestFiles}` | per-category FTP directories |

Not in configuration: **CORS origins are hardcoded** in `StringConstants.apiAllowedOrigins` (`https://*.captainasadgroupofcompanies.com`, `https://localhost:3000/3001`, `http://localhost:3000/3001`) — changing an allowed origin requires a code change and redeploy.

Local run profiles (`launchSettings.json`): `https://localhost:7130` + `http://localhost:5016`, browser opens `/scalar`.

### 8.2 UI configuration

| Variable | `.env` (local) | `.env.qa` | `.env.prod` |
|---|---|---|---|
| `NEXT_PUBLIC_CAG_ADMIN_API_BASE_URL` | `https://localhost:7130/api/` | `https://qa-api-admin.…/api/` | `https://api-admin.…/api/` |
| `NEXT_PUBLIC_CAG_ADMIN_UI_BASE_URL` | `https://localhost:3000` | `https://qa-web-admin.…` | `https://admin.…` |
| `NEXTAUTH_URL` | `https://localhost:3000` | qa host | prod host |
| `NEXTAUTH_SECRET` | same value in all three | | |
| `JWT_SECRET` | same value in all three | | |
| `NODE_ENV` | **`production`** (local!) | — | — |

`NODE_ENV=production` in the local `.env` has two live effects: `axios.ts` skips the `https.Agent({rejectUnauthorized:false})` (self-signed dev API certs are rejected), and the NextAuth session cookie is marked `secure`. This is the first thing to check when local login fails.

All three env files carry **identical** `JWT_SECRET` and `NEXTAUTH_SECRET` values — dev, QA, and prod share signing keys, so a token minted locally is valid in production.

### 8.3 Secrets posture

Committed to source control, in plaintext:

- MySQL host, username, and password (dev and prod, same credentials) — `appsettings.development.json`, `appsettings.production.json`
- JWT signing key — `AppSettings:Token` and, duplicated, `JWT_SECRET` in three `.env` files
- `NEXTAUTH_SECRET` — three `.env` files
- FTP host, username, password — both appsettings files
- TLS private key — `CAG.Admin.UI/certificates/localhost-key.pem` (localhost only, low impact)

Both repositories have real history, so rotation alone does not remove these — history rewriting or credential retirement is required. See §10.

---

## 9. Build and deploy pipeline

### 9.1 Local development

```bash
# API — from CAG.Admin.API/
dotnet restore CAG.Admin.API/CAG.Admin.API.sln
dotnet build   CAG.Admin.API/CAG.Admin.API.sln
dotnet run --project CAG.Admin.API/CAG.Admin.API.csproj      # https://localhost:7130
#   docs: /scalar/v1    spec: /openapi/v1.json

# UI — from CAG.Admin.UI/
npm install
npm run dev      # next dev --experimental-https --turbopack → https://localhost:3000
npm run lint     # eslint: next/core-web-vitals + next/typescript
npx tsc --noEmit
npm run build && npm run start
```

### 9.2 Tests

**There are none, in either tier.**

- `CAG.Admin.API.UnitTests/` contains only a stale `obj/` directory. The `.csproj` no longer exists and the project is absent from the solution — `dotnet test` finds nothing to run.
- The UI has no test runner, no test files, and no test script in `package.json`.
- `CAG.Admin.UI/UI_TEST_FLOWS.md` is a hand-written manual QA script (dated May 18, 2026, covering the ClientRiderConfig synchronization change), not automation.

Every change is validated by hand against a shared dev database.

### 9.3 CI/CD

**There is no CI.** `CAG.Admin.API/.github/workflows/` exists but is **empty**; the UI repository has no workflows directory. There is no docker-compose file anywhere. Nothing builds, lints, or tests on push; nothing gates a merge.

### 9.4 Container images

Both repositories ship a standalone `Dockerfile`, built and run independently.

**API** — multi-stage, `mcr.microsoft.com/dotnet/sdk:9.0-alpine` → `aspnet:9.0-alpine`:

```
restore → build (Release) → publish (/p:UseAppHost=false) → runtime
runtime adds: iputils-ping, net-tools, curl, icu-libs, tzdata
non-root user `app`; EXPOSE 8080; ASPNETCORE_URLS=http://*:8080
ASPNETCORE_ENVIRONMENT=Production
```

Note the Dockerfile `COPY`s only `CAG.Admin.API/CAG.Admin.API.csproj` before `dotnet restore`, then `COPY . .` — so the three sibling project files are restored during build rather than in the cached restore layer, defeating most of the layer-caching benefit.

**UI** — multi-stage, `node:22-alpine`:

```
deps    → npm ci
builder → selects env by APP_ENV:  qa → cp .env.qa .env.production
                                   prod → cp .env.prod .env.production
        → npm run build
runner  → non-root `app`; EXPOSE 3000; CMD npm run start
```

`APP_ENV` is consumed but never declared as an `ARG`, so it is empty unless the build passes it — the silent default is the "Using default production environment" branch, which leaves `.env.production` absent and falls back to the committed `.env` (the one with `NODE_ENV=production` and localhost URLs). The runner stage also copies the **entire** builder `/app` (including `node_modules` and source) rather than a standalone output, producing a much larger image than Next.js standalone mode would.

Typo in the UI Dockerfile: `getent passed app` should be `getent passwd app`. It is masked by the `||` fallback, so `adduser` runs every build.

### 9.5 Deployment topology (inferred)

Hosts implied by configuration: `admin.captainasadgroupofcompanies.com` (UI prod), `api-admin.…` (API prod), `qa-web-admin.…` / `qa-api-admin.…` (QA), with MySQL and FTP on `50.62.221.135` / `captainasadgroupofcompanies.com`. How images reach those hosts is not recorded in either repository.

---

## 10. Known technical debt and observations

Ordered by consequence. Items 1–5 are security or correctness; the rest are maintainability.

### 1. Authorization is enforced only in the browser

The `Role` / `Permission` / `RolePermission` / `PageModule` tables and the `ModulePermissions` claim are checked exclusively by `middleware.ts` and `useHasPermission`. The API applies a blanket `[Authorize]` — authentication, not authorization. **Any user holding any valid token can invoke any endpoint directly**, including `PUT api/permissions/update`, which rewrites the role-permission matrix, and every delete endpoint. Multi-tenant `CompanyIds` scoping is likewise advisory — it applies only where a repository chose to filter.

*Direction:* add policy-based authorization mapping module codes to endpoints, enforced server-side; treat the UI checks as presentation only.

### 2. Credentials committed in plaintext, shared across environments

Live MySQL credentials (dev **and** prod, identical), the JWT signing key, `NEXTAUTH_SECRET`, and FTP credentials are all in version control (§8.3). Because dev/QA/prod share signing keys, **a token minted against the dev database authenticates against production**. Both repositories have real history, so rotation must be paired with history remediation.

### 3. Middleware ordering breaks error handling and CORS

`ExceptionHandlingMiddleware` is registered *inside* `AuthenticationMiddleware`, so the `AdminAPIException(Unauthorized)` thrown on a malformed bearer token is **never caught** — the caller receives an unhandled 500 instead of the intended structured 401. `UseCors` runs after both, so responses generated by either middleware carry no CORS headers and the browser reports an opaque CORS failure rather than the real error.

*Fix:* `UseCors` → `ExceptionHandlingMiddleware` → `AuthenticationMiddleware` → `UseAuthentication`.

### 4. `AuthController` bypasses the error pipeline and leaks exception text

Both actions wrap their body in `try/catch` and return `BadRequest(ex.Message)`, sidestepping `ExceptionHandlingMiddleware` and echoing raw exception text to an **unauthenticated** caller — on a DB failure that includes connection details. It is also the only controller without `[Authorize]`; with no fallback policy configured it is anonymous by default, which is correct for `login` but means the anonymity is implicit rather than declared (`[AllowAnonymous]` would state the intent).

### 5. Fire-and-forget logging on a scoped dependency

`ExceptionHandlingMiddleware:78` — `_ = Task.Run(() => fileService.AppendAsync(log))` — captures a **scoped** `IFileService` and runs it past the end of the request scope. Under load this can throw `ObjectDisposedException` inside an unobserved task, silently losing error logs precisely when they matter most.

### 6. No tests, no CI

Zero automated tests in either tier; an empty workflows directory. Every change is verified manually against a shared dev database. Given a reflection-driven SQL layer where a property rename breaks persistence at *runtime* (§7), the absence of even smoke tests over the repositories is the highest-leverage gap in the engineering process. *(Judgement.)*

### 7. Schema has no migration history

Hand-applied DDL, a schema dump ten weeks staler than its CSV catalog, and a stray `temp` table in the dump (§4.7). Nothing links a deployed API build to the schema version it requires, and a rollback has no defined database counterpart.

### 8. Mixed collations

22 tables are `latin1_swedish_ci`, 30 are `utf8mb4_general_ci`. The `latin1` set includes `LeaveRequest`, `Payroll`, `Batch`, `DocumentType`, and `RolePermission`. Any non-Latin text (Arabic names, addresses) written to a `latin1` column is corrupted on write, irrecoverably.

### 9. Reflection-based SQL has no schema verification

`DapperHelper` assumes property name ≡ column name. A renamed property, or one added without a matching column, produces a runtime SQL error on first write — not a build error, not a startup error. Table names are constructor string literals, invisible to rename refactors and static analysis.

### 10. Response-envelope coupling is silent when broken

The UI's `unwrap()` reads `res.data.data`. An endpoint returning a bare object yields `undefined` in the UI with no error on either side. There is no shared contract artifact — no generated client, no OpenAPI-derived types — despite the API publishing an OpenAPI document that could generate them.

### 11. Raw DB models bound from request bodies

`AddClient(Client)`, `AddRider(Rider)`, `UpdateVehicle(Vehicle)`, `UpdateTicket(int, Helpdesk)`, `AddSimCard(SimCard)`, `Add(Batch)` accept entity types directly, exposing every column-backed property (including keys, audit fields, and status columns) to mass assignment.

### 12. Validation deferred to the database

Two static validators cover riders and bank details; everything else relies on unique and check constraints. A duplicate import row surfaces as a driver exception mapped to **500**, not the `DuplicateEntityExists` → **409** that the exception enum already defines.

### 13. Synchronous bulk imports

Attendance, rider-order, and sales-cash imports parse whole workbooks and write thousands of rows inside the HTTP request. There is no queue, no progress reporting, and no partial-failure resumption — a timeout leaves the import half-applied, recoverable only through the `*UploadLog` tables.

### 14. No pagination anywhere

Every list endpoint returns its full result set; AG Grid filters client-side. `useGetAllRiders` pulls 1,778 riders joined across 8 tables on every page load. `OrderList` (115k rows) will be the first to force a change.

### 15. Dual-store writes are not transactional

File uploads write FTP bytes and a MySQL metadata row with no coordination and no reconciliation (§7.4), so both orphan directions are reachable.

### 16. `IMemoryCache` will not survive scaling

In-process cache in 4 controllers. A second replica serves inconsistent cached images with no invalidation path between instances.

### 17. Dead and stray code

`BatchVehicleCategoryController` — registered, injects a service, declares no actions. `CAG.Admin.API.UnitTests/` — an `obj/` directory with no project. `temp_backup.cs`, `ANALYSIS_ClientRiderConfig_ClientUserId_Mismatch.md`, `IMPACT_ANALYSIS_Functionality_Check.md`, `QUICK_REFERENCE_RiderId_Mismatch.md` at the API repo root — one-off investigation notes. Unused `SqlClient` packages and `using`. A `temp` table in the schema dump.

### 18. Inconsistent API conventions

Verb-suffixed and REST-style routes coexist; `POST api/attendance/orderList/import` sits in the wrong controller; API versioning is configured but inert; `[Authorize]` is applied redundantly at both class and method level throughout. `ITokenSerivce` and `SqlConnectionFactory .cs` (with a space in the filename) carry typos into the public surface.

---

## Appendix — quick reference

| Question | Answer |
|---|---|
| How many deployable services? | 2 (API, UI) |
| How many API endpoints? | 167 across 24 controllers |
| How many DB tables / models? | 52 tables, 46 C# models |
| Stored procedures / views / triggers? | 2 / 0 / 0 |
| ORM? | None — Dapper + reflection-built SQL |
| Migrations? | None — hand-applied DDL |
| Tests? | None |
| CI? | None (empty workflows directory) |
| Message broker / cache server / search cluster? | None / None / None |
| Where do uploaded files live? | FTP server; MySQL stores metadata only |
| What must match across the two repos? | UI `JWT_SECRET` ≡ API `AppSettings:Token` |
| What breaks when a UI route is added? | Missing `RolePageCode` entry → redirect to sign-in |
