# 06 — Order Values: Two Order Values & Rider Category on Onboarding (Milestone 1)

> Source: `CAG_Phase_II.docx` → *Add Two Order Values (Milestone 1)* + *Order Value Update*
> Modules touched: Order Values (`api/ordervalue`), Onboarding wizard, Payroll.
> Related docs: [order value endpoints](../implementation-impact-analysis.md),
> [onboarding](../hr-workflow-onboarding.md).

## 1. Requirement (as specified)

- During **Rider Onboarding**, add a dropdown to select **Rider Category** for the new **Free Visa
  Order Value**.
- **Question in doc:** "Company bike or Own bike applies for Free Visa?" → answer given: the order
  types available in Order Values should be shown as a dropdown during onboarding; based on the
  selected **Order Type**, payroll should auto-calculate using the order values configured for that
  type.
- Add an option to **add the order value type**.
- Add a **dropdown in rider onboarding for order value**.
- **Order Value Update:** add **two order values**.

## 2. Impact & Changes

### UI (`CAG.Admin.UI`)
- **Onboarding wizard** (`components/modals/rider/basic-info-form.tsx`) — new **Order Type**
  dropdown sourced from the Order Values master (same values as the Order module). This is the same
  field referenced by [02](02-rider-management-status.md) onboarding update.
- **Order Values admin** (`(pages)/Finance/Order-Values/**`) — support adding an **order value type**
  and configuring **two order values** (e.g. a Free-Visa value alongside the standard).

### API / DB (`CAG.Admin.API`)
- **Order value type master** — allow adding types (a configurable master, same pattern as
  [12](12-company-expenses.md) categories and [13](13-mandoob-activities.md) activity types).
- **Two order values** — extend `OrderValue` to carry a second value (or a type-keyed set of values).
  Confirm data shape (see questions).
- **Onboarding persistence** — store the selected Order Type on the rider so payroll can resolve the
  right order value.
- **Payroll** — `PayrollService` resolves the order value by the rider's Order Type when computing
  order revenue.

### Cross-cutting
- The Order Type dropdown is **shared with** [02](02-rider-management-status.md) (onboarding update)
  — build it once.
- Feeds **payroll** and the **Performance page** earnings ([03](03-rider-performance-page.md)).
- Ties to [07](07-part-time-free-id-management.md): Part-Time payroll uses order counts × order value.

## 3. Open Questions & Suggestions

### UI-side
- **Q:** "Rider Category" vs "Order Type" — the doc uses both. Are they the same dropdown or two?
  💡 Treat as **one** dropdown ("Order Type", values from Order Values). The doc's own clarification
  collapses them. Confirm with client.
- **Q:** At which onboarding step does the Order Type dropdown appear?
  💡 Basic Info step (alongside Vehicle Type / Employment Type), so payroll has it from day one.
- **Q:** Order-Values admin — how are the "two order values" labelled for the user (e.g. "Standard"
  vs "Free Visa")?
  💡 Label by order-value **type**; the second value is just another type row, not a hardcoded
  "value 2".

### API / Data-side
- **Q:** "Add two order values" — is this two columns on one `OrderValue` row, or two rows keyed by
  type? (The latter scales; the former is fixed at two.)
  💡 **Two rows keyed by order-value type** (a master + per-type value), not two fixed columns —
  matches "add the order value type" and avoids a schema change every time a new value is needed.
- **Q:** What is the current `OrderValue` shape and how does payroll read it today?
  💡 Inspect `OrderValueRepository` / `PayrollService`; confirm the join key (batch / vehicle
  category) before adding the type dimension.
- **Q:** "Company bike or Own bike applies for Free Visa?" — is Free Visa gated by vehicle ownership?
  💡 Per the doc's own answer, do **not** hard-gate; expose all order types and let the selected type
  drive the value. Confirm no ownership rule is needed.
- **Q:** Order Type stored on the rider — new column on `Rider`, or on `ClientRiderConfig`?
  💡 On `Rider` (it's an employment attribute), unless it can change per client assignment — then
  `ClientRiderConfig`. Confirm.

### Business / Product
- **Q:** Provide the definitive **Order Type list** and the **two values** each should carry.
  💡 Client to supply; we seed the master and wire the dropdown + payroll lookup.
- **Q:** Does changing a rider's Order Type retroactively affect past payroll, or only future?
  💡 Future only; past payroll rows keep the value used at the time. Confirm.
