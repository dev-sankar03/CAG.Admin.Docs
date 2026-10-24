# Cash Collection & Handover (bug sheet #53)

Branch `feature/phase2_requirements` (API + UI), 2026-10-24 — not on develop / QA yet.

HR and other departments take cash at the office (Admin Fees, Processing Fees, Previous Balance, Akama renewal…). This module records each collection, its handover and the Admin's confirmation, so collections per department, pending handovers and received amounts can be tracked without delaying the person at the counter.

## Workflow

| Status | Who | What |
|---|---|---|
| **Collected** ("With collector") | anyone with Edit on Cash Collection | records rider (optional), what it is for (a rider expense category, or a description), amount, date, remarks. Department = the recorder's role. |
| **Handed over** | the collector (or an Admin) | selects their collections → *Hand over* → optional "Handed to" (an Admin user). |
| **Received** | **Admins only** | selects collections → *Confirm received*. |
| **Cancelled** | the collector (or an Admin), while not Received | with a reason. |

**Credit the rider's expenses** (tick on the form, needs a rider and a category): when the collection is Received, a credit (negative amount, `Source = 'CashCollection'`, reference `CC-<id>`) is added to the rider's expense ledger in that category, so payroll does not deduct the same amount from salary. Without the tick the ledger is not touched.

## API

`api/cash-collection` — `GET` (from / to / companyIds), `POST`, `PUT {id}` (Collected only), `POST handover` {ids, handedOverTo}, `POST receive` {ids}, `POST {id}/cancel` {reason}. `CashCollectionService` checks module `CAG_CASH_COLLECTION` (View to read, Edit to write; riders refused), Admin for receipt, and the caller's companies (the rider's company, or the chosen company).

Script #37 `2026-10-24_CashCollectionModule.sql`: table `CashCollection` + PageModule `CAG_CASH_COLLECTION`, every role starting at its **Riders** level (Admin…Coordinator Edit, Reporter View, Mandoob none) — change in Admin → Permissions.

## UI

Sidebar **Cash Collection** (`/Cash-Collection`): status filter (default *Pending* = not received), month filter, a department × status summary above the grid, row selection for *Hand over* / *Confirm received*, Edit / Cancel per row, Activity log (Admins).

## Defaults chosen (not confirmed by the client)

1. Receipt is confirmed by **Admins** — no new Accountant role.
2. **No approval step** before collecting (the requirement says "where required"; none was named).
3. The rider ledger is credited **only when ticked**, at receipt.
4. Recording is open to every role with Edit on the module (starting from their Riders level).

Tested on Dev (service level): HR records → department HR + rider's company; credit without rider refused; HR can't confirm receipt; Admin receipt writes the −12.50 credit; cancel; no double receipt; riders refused. Test rows removed.
