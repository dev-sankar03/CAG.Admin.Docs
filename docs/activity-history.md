# Activity history — modules (bug sheet #42)

Branch `feature/phase2_requirements` (API + UI), 2026-10-24 — not on develop / QA yet.

"Who added / changed / deleted what, and when" for the Car EMI, Vehicle, Company Expenses, HR (Workflow, Attendance imports), Inventory (properties, SIM cards), Leave Management, Passport Request, Mandoob Activities and Cash Collection modules. A rider's own history stays in `RiderActivity` (rider page → Activities, see [Rider Management](rider-management.md)).

## Recording

- `Filters/RecordActivityFilter` (global MVC filter, next to `RiderActivityFilter`) runs after every successful non-GET request of the endpoints listed in its `Endpoints` table and writes one row to **`RecordActivity`** (script #35): module, record type ("Vehicle", "Expense", "SIM card"…), record id, action ("Updated vehicle"), endpoint, user, time, the values sent (`details`, files by name), and the record's fields **before / after** (`changes`, from a fixed `SELECT * FROM <table> WHERE <key> = @Id` per table; createdAt/By and updatedAt/By left out).
- Where the id comes from: an argument (`id`, `ticketId`…), a body property (`VehicleId`, `PropertyId`…), the id an add returns, or a parent lookup (a vehicle photo's vehicle, a leave comment's request, a vehicle document's vehicle). Imports (attendance, shift sheet, split company expense) are recorded without a record id.
- Vehicle documents are recorded only when the document belongs to a vehicle (Source = "Vehicle"); rider documents stay in RiderActivity only. Assigning / unassigning a rider (`Rider.UpdateVehicle`) is recorded on the vehicle.
- `companyId` is stored from the record's row (or its rider's company) and the read is scoped by it; records without a company (types, categories, imports) are visible to every Admin.
- A failed write is logged and never fails the request. If the table is missing, nothing is recorded.

## Reading

- `GET api/activity?module=VEHICLE&recordId=VH…&page=1&pageSize=50` — **Admins only** (the rule the client chose for rider Activities on 2026-10-14). Modules: `VEHICLE, CAR_EMI, COMPANY_EXPENSE, HR, INVENTORY, LEAVE, PASSPORT, MANDOOB, CASH_COLLECTION`.
- UI: an **Activity log** button (Admins only) on each module page (`GenericPage` prop `activityModule`), and *Change history* on a vehicle's Activity tab (one record).

## Created by / Updated by

All the modules' tables already store `createdBy / updatedBy`. The grids of Vehicles, Car EMI, Inventory, SIM cards, Leave, Passport and HR Workflow now show **Created By** and **Updated By** (user names from `GET api/user`, cached 10 min; the two dates are in the Columns menu) — `GenericPage` prop `showAuditColumns`, `utils/audit-columns.tsx`. Company Expenses and Mandoob Activities already had them. The CSV export includes them (`buildCsvFromColumns` now reads a column's `valueGetter`).

Tested on Dev through the filter itself (vehicle update recorded with its before / after, rider document delete not recorded, non-Admin refused); test rows removed.
