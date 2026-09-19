# 08 — Rider More Details: Remove Tabs, Scrolling Layout (Milestone 1)

> Source: `CAG_Phase_II.docx` → *Rider More Details (Milestone 1)*
> Modules touched: Rider detail page (UI only).
> Related docs: [rider detail page](../rider-management.md),
> [grid/tab height contract](../partner-company-management.md),
> [ui-data-layer](../frontend-application-shell.md).

## 1. Requirement (as specified)

- **Remove tabs** from the rider detail page.
- Use a **scrolling layout** with a **second row**.

(Short and UI-only, but it interacts with several other requirements that add sections to this page.)

## 2. Impact & Changes

### UI (`CAG.Admin.UI`)
- **Rider detail** (`(details)/Rider/[riderId]/index.tsx`) currently uses a `TabBar`
  (`components/details/rider/*` tabs: rider, employment, property, vehicle, bank-details, expense,
  workflow, performance, client-mapping-history, documents). This requirement replaces the tab
  switcher with a **single scrolling page** that stacks the sections, in a **two-row/column** layout.
- Each existing tab component becomes a **section** on the scroll page (they're already isolated
  components, so this is mostly recomposition, not rewrites).
- ⚠️ **Height-contract caution:** the embedded grids (Documents, Expense, Property) rely on a bounded
  ancestor height under `(details)/layout.tsx`, which is **unbounded** (`min-h-screen`). In a tab
  layout only one grid mounts at a time; in a **scrolling** layout several mount together, so each
  grid section needs its own explicit height (not `flex-1` competing for viewport). See the exact
  pitfall in [tab height contract](../partner-company-management.md) —
  the same `h-full`/`flex` trap applies here.

### API / DB
- **None.** Pure UI recomposition; the data hooks are unchanged.

### Cross-cutting
- This layout is the **canvas** for several other requirements that add sections to the rider page:
  [05](05-complaint-section.md) (Complaints), [03](03-rider-performance-page.md) (or a link to the
  Performance page), [04](04-rider-expense.md) (Expense table). Build the scroll shell first so those
  drop in as sections.

## 3. Open Questions & Suggestions

### UI-side
- **Q:** "Second row" — does this mean a two-column layout (two sections side by side per row), or
  literally a second header row of quick info?
  💡 A responsive two-column grid of section cards (collapses to one column on mobile), with a
  compact rider-summary header pinned at top — matches "scrolling layout with a second row" and the
  Performance-page sample in [03](03-rider-performance-page.md).
- **Q:** With tabs gone, how do users jump to a section on a long page?
  💡 A sticky in-page section nav (anchor links) or a floating "jump to" — keeps the tab-like speed
  without the tab component.
- **Q:** Which sections stay, and in what order? (Tabs today: rider, employment, property, vehicle,
  bank, expense, workflow, performance, client-mapping, documents.)
  💡 Propose order: Summary header → Rider/Employment → Documents → Expense → Vehicle/Property →
  Bank → Client Mapping → Workflow → Complaints. Confirm with client.
- **Q:** Should heavy sections (Documents, Expense grids) lazy-load on scroll to avoid mounting all
  grids at once?
  💡 Yes — lazy-mount grid sections when scrolled into view (avoids the multi-grid height/perf
  problem and the initial-load cost).
- **Q:** Keep the unsaved-changes guard that the current tab-switch flow uses?
  💡 Keep it at the page level (on navigate-away) since there are no tab switches to intercept
  anymore.

### API / Data-side
- **Q:** Any endpoints that were only called on tab-activation now fire on page load — perf concern?
  💡 Pair with lazy-loading (above); keep per-section queries `enabled` only when the section is
  visible, using the existing `enabled`/`staleTime` hook conventions.

### Business / Product
- **Q:** Is this purely the Rider detail page, or should the Partner-Company detail page
  (also tab-based, [partner-company](../partner-company-management.md)) get the same
  treatment?
  💡 Scope to Rider detail as written; note Partner-Company as a possible follow-up for consistency.
