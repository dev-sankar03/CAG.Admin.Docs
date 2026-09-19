# CAG Phase II — Requirements Analysis (per-requirement detail)

> **Companion to the master analysis.** The repo's authoritative, effort-estimated Phase II
> assessment is [`../implementation-impact-analysis.md`](../implementation-impact-analysis.md)
> (requirement mapping, task IDs, ~270 person-day estimate, 14 open questions) and its status is
> tracked in [`../implementation-tracker.md`](../implementation-tracker.md). **This folder is the
> per-requirement detail companion** — one file per requirement set, each with the UI-side and
> API-side question/suggestion breakdown. Where the two differ on a fact, the master analysis (which
> carries code line numbers) wins; discrepancies are noted inline.

Analysis of **`CAG_Phase_II.docx`** ("CAG Enhancement List"), split into one file per requirement
set. Each file follows the same structure:

1. **Requirement (as specified)** — what the document asks for, kept faithful to the source.
2. **Impact & Changes** — what has to change, split into **UI** (`CAG.Admin.UI`), **API/DB**
   (`CAG.Admin.API`), and cross-cutting effects on other modules. Grounded in the current codebase
   (see [`../docs/`](../implementation-impact-analysis.md)) — existing files, tables, enums and known behaviours are
   named so the impact is concrete, not generic.
3. **Open Questions & Suggestions** — the questions that must be answered before build, split into
   **UI-side**, **API/Data-side**, and **Business/Product**, each with a 💡 **suggested answer**.

> These are analysis documents, not final specs. The 💡 suggestions are recommendations to confirm
> with the client, not decisions already made. Where a requirement collides with a known codebase
> behaviour, it is flagged with ⚠️ and linked to [`../docs/combined/known-behaviours.md`](../known-behaviours.md).

---

## Requirement files

| # | Requirement set | Milestone | File |
|---|---|---|---|
| 01 | Main Dashboard revamp (cards, orders, Finance Summary, expiring-car quota) | M2 | [01-main-dashboard.md](01-main-dashboard.md) |
| 02 | Rider Management — Company & Client status separation, onboarding update | M1 | [02-rider-management-status.md](02-rider-management-status.md) |
| 03 | Rider Performance Page & Export | M2 | [03-rider-performance-page.md](03-rider-performance-page.md) |
| 04 | Rider Expense — history, bulk import, table view, +/- | M1 | [04-rider-expense.md](04-rider-expense.md) |
| 05 | Complaint Section (comments on rider) | M1 | [05-complaint-section.md](05-complaint-section.md) |
| 06 | Order Values — two order values, rider category on onboarding | M1 | [06-order-values.md](06-order-values.md) |
| 07 | Part-Time & Free ID Management (new module) | M1 | [07-part-time-free-id-management.md](07-part-time-free-id-management.md) |
| 08 | Rider More Details — remove tabs, scrolling layout | M1 | [08-rider-more-details.md](08-rider-more-details.md) |
| 09 | Vacation Management — edit, overdue logic, audit | M1 | [09-vacation-management.md](09-vacation-management.md) |
| 10 | Sales Cash — payment type, print receipt, audit | M1 | [10-sales-cash.md](10-sales-cash.md) |
| 11 | Documents Module — UI, optional expiry, view, multi-file | M1 | [11-documents-module.md](11-documents-module.md) |
| 12 | Company Expenses Module (new module) | M2 | [12-company-expenses.md](12-company-expenses.md) |
| 13 | Mandoob Activities (new module) | M1/M2 | [13-mandoob-activities.md](13-mandoob-activities.md) |
| 14 | Miscellaneous changes (8 items) | M1 | [14-misc-changes.md](14-misc-changes.md) |
| 15 | Shareholder Profit Calculation | M2 | [15-shareholder-profit.md](15-shareholder-profit.md) |

---

## Milestone summary

**Milestone 1 (near-term):** 02, 04, 05, 06, 07, 08, 09, 10, 11, 13 (partial), 14.
**Milestone 2 (later):** 01, 03, 12, 13 (follow-up dashboard), 15.

The milestone tags come from the document's own headings; where a set spans both, the file notes
which parts fall where.

---

## Cross-requirement themes

Several requirements share a spine — decide these once, centrally, before building any single file:

| Theme | Appears in | Central decision needed |
|---|---|---|
| **Client Status** (new concept, distinct from the existing rider/company status) | 02, 03, 07 | The canonical status list, and whether it attaches to Client User ID or Rider — see [02](02-rider-management-status.md) |
| **Free ID → Part-Time flow** | 02, 06, 07 | Free ID lifecycle and how it feeds the Part-Time module |
| **Server-side status/permission enforcement** | 02, 07, 14 (#7) | ⚠️ Currently there is **no** server-side permission check ([known-behaviours 🔴](../known-behaviours.md)); restricting status changes needs one built |
| **Expense ledger** | 04, 03, 12 | The `RiderExpense` migration ([data-model](../database-access-layer.md)) already scaffolds this — align all three on it |
| **Audit (created/updated by + timestamp)** | 09, 10, 12, 13 | A consistent audit pattern; the DB already has `Created*/Updated*` columns everywhere ([data-model](../database-access-layer.md)) |
| **Category/type masters** | 12 (expense categories), 13 (activity types), 06 (order value types) | One "configurable master + dropdown" pattern reused three times |
| **Vacation ↔ status automation** | 09, 14 (#6) | The Vacation/Vacation-Overdue auto-status rules, currently a GET side-effect ([known-behaviours](../known-behaviours.md)) |

---

## How the impact analysis reads the codebase

The current system is documented in [`../docs/`](../implementation-impact-analysis.md). Key references used throughout
these files:

- Rider status model & lifecycle — [docs/modules/rider](../rider-management.md)
- Rider↔vehicle assignment (auto-unassign on status) — [docs/…/rider-vehicle-assignment](../rider-management.md)
- Documents/expiry, multi-file, mandatory-expiry — [docs/modules/documents](../document-management.md)
- The expense migration — [docs/combined/data-model](../database-access-layer.md)
- Auth/permissions/scoping — [docs/combined/cross-cutting](../authentication-authorization.md)
- Known bugs this phase can fix — [docs/combined/known-behaviours](../known-behaviours.md)
