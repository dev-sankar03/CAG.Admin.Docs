# Status Badge Design System (Audit & Proposal)

## 0. Purpose & scope

Every module that shows a lifecycle state — Rider status, Vehicle/Company active flag, Leave Request status, Passport Request status, Helpdesk status, HR task status, attendance day state, document expiry — currently renders it with its **own, independently written** badge component and its **own, independently chosen** colors. Nothing is shared except the general shape ("a pill of colored text").

This document is the requested **audit + proposal**: what exists today, where it disagrees with itself, and a single standard to replace it with. It does not change any code — see §9 for the migration this would require and §10 for the effort estimate.

**Repo:** `CAG.Admin.UI` (all paths below are relative to it unless stated otherwise).

## 1. Complete audit — every status/chip implementation found

| # | File | Renders | Values (raw) | Background | Text | Border | Radius | Padding / size |
|---|---|---|---|---|---|---|---|---|
| 1 | `components/grid/status-bar.tsx` (`StatusBar`) | Vehicle.isActive, Company.isActive, isLoggedIn (boolean) | Active/Inactive, Logged In/Logged Out | `green-500/40` or `red-500/60` (opacity layer, **not** a flat token) | `green-800` / `red-800` | `border-green-800` / `border-red-800` | `rounded-md` | custom two-`div` overlay, `h-6`, no fixed padding |
| 2 | `components/grid/rider-status.tsx` (`RiderStatusBadge`) | Rider.status (grid) | Onboarding, Visa Process, Local Transfer, Free Id, Active, Suspended, Terminated, Cancelled, Vacation, Vacation Overdue, Supervisor, Operational Manager, HR, Akhama Transfer | 14 **literal hex** values, e.g. `bg-[#DCFCE7]` | 14 literal hex, e.g. `text-[#166534]` | 14 literal hex, e.g. `border-[#BBF7D0]` | `rounded-full` | `px-2 py-1 text-[12px] font-medium` |
| 3 | `components/details/rider/rider-page-header.tsx` (`riderStatusColorMap`, inline) | **Same** Rider.status, on the detail page header | Onboarding, Visa Process, Local Transfer, Free Id, Active, Suspended, Terminated, Cancelled, Vacation | Tailwind tokens, e.g. `bg-green-100` | e.g. `text-green-800` | none | `rounded-full` | `px-2.5 py-0.5 text-[11px] font-semibold` |
| 4 | `components/grid/passport-request-status-badge.tsx` | PassportRequest.status | Passport Requested, Passport Received, Collected By Rider, Approved, Rejected, Closed | `amber/blue/indigo/emerald/rose/slate-100` | matching `-800`/`-700` | `border border-current` (border = text color) | `rounded-full` | `px-2 py-1 text-[12px] font-medium` |
| 5 | `components/grid/helpdesk-status-badge.tsx` | Helpdesk.status | Open, Closed (+ unused future `PENDING`, `REOPENED`) | `emerald/slate/yellow/blue-100` | matching | `border border-current` | `rounded-full` | `px-2 py-1 text-[12px] font-medium` |
| 6 | `components/grid/task-status.tsx` (`TaskStatusBadge`) | HR TaskStatus | In Progress, Completed, Waiting, Failed, Rejected | 5 **literal hex** values | 5 literal hex | `border border-current` | `rounded-full` | `px-2 py-1 text-[12px] font-medium` |
| 7 | `components/grid/attendance-log-status.tsx` (`LogStatusBadge`) | attendance import row (boolean) | Processed / Cancelled | `green-100` / `red-100` | `green-700` / `red-700` | none | `rounded-full` | `px-2 py-0.5 text-xs font-semibold` |
| 8 | `components/grid/leave-request-buttons.tsx` (`LeaveRequestActionButtons` — misnamed, renders a badge not buttons) | LeaveStatus | Pending Review, Approved, On Hold, Rejected, Cancelled, Supervisor Approved | `yellow/green/amber/red/gray/blue-100` | matching `-800` | `border border-{color}-300` (explicit token, not `-current`) | `rounded-full` | `px-2 py-1 text-[12px] font-medium` |
| 9 | `(pages)/HR/Attendance/components/attendance-status.tsx` | Attendance calendar day state | Worked, No Show, Late Login, Suspended, No Shifts, Absent | `emerald/red/purple/amber/slate/rose-50` | matching `-700`/`-600`/`-400` | `border border-{color}-200` | `rounded-md`-ish pill (inline, calendar cell) | small, calendar-cell sized |
| 10 | `utils/expiry.ts` (`getExpiryBadge`) + `components/file-uploads/document-tab.tsx` | Document expiry | No Expiry, Expired, Expiring in Nd, Valid | `gray/red/yellow/green-100` | matching `-600`/`-700`/`-800` | none | `rounded-full` | `h-6 px-2.5 text-[11px] font-semibold leading-none` |
| 11 | `components/grid/passport-request-days-badge.tsx`, `helpdesk-days-badge.tsx` | "days open" SLA indicator (not a status, but a badge) | N/A, ≤3/7d, ≤7–8d, >7–8d | **solid** `emerald-600`/`amber-500`/`rose-600` (no pastel, no border) | white | none | `rounded-full` | `px-2 py-1 text-[12px] font-medium` |
| 12 | `components/grid/passport-request-type-badge.tsx`, `helpdesk-type-badge.tsx`, `hr-tasks.tsx`, `vehicle-registered-on.tsx` | category/type tags (not lifecycle status) | Vacation/Baldiya/Renewal/…, SOS/Shift/Vehicle/General, Document Collection/Tasriya/…, Company/EmployeeOwned | one arbitrary Tailwind hue per value, `-50`/`-100` | matching | `border-current` or none, inconsistently | `rounded-full` | `px-2 py-1 text-[12px] font-medium` |
| 13 | `components/grid/vehicle-owner-type.tsx` (`OwnerType`) | Vehicle owner type | Company, EmployeeOwned, Rental, Installment | opacity-layer trick again (same as #1) | plain `text-xs`, no color | `border` + `rounded-md` | same two-`div` overlay as #1 |
| 14 | `constants/grid-props/sim-cards.tsx` (inline renderer) | SIM assignment | Available / assigned | `green-100` or none | `green-700` or default | `border-green-300` or none | **`rounded-lg`** | `px-2 py-1 text-xs font-medium` |

**14 independent implementations, at least 4 border-radius values (`full`/`md`/`lg`/calendar-cell), at least 4 padding/font-size recipes, at least 4 border conventions (none / `border-current` / explicit `-200`/`-300` token / literal hex), and 2 fundamentally different rendering techniques** (flat `<span>` vs. an opacity-layered two-`div` overlay used only in #1 and #13).

## 2. Every unique status value in the app today

Grouped by the domain that owns it (domain boundaries matter for the proposed component — see §7):

| Domain | Values |
|---|---|
| **Rider** (`RiderStatus` enum) | Onboarding, Visa Process, Local Transfer, Free ID, Active, Suspended, Terminated, Cancelled, Vacation, Vacation Overdue, *Supervisor, Operational Manager, HR, Akhama Transfer* (see §3.4 — these last four are roles, not lifecycle states, but live in the same enum/badge today) |
| **Boolean active flag** (Vehicle, Company, generic "logged in") | Active, Inactive, Logged In, Logged Out |
| **Leave Request** (`LeaveStatus` enum) | Pending Review, Approved, On Hold, Rejected, Cancelled, Supervisor Approved |
| **Passport Request** (`PassportRequestStatusEnum`) | Passport Requested, Passport Received, Collected By Rider, Approved, Rejected, Closed |
| **Helpdesk** (`HelpdeskStatusEnum`) | Open, Closed (Pending, Reopened declared but not wired to any real flow) |
| **HR Task** (`TaskStatus` enum) | In Progress, Completed, Waiting, Failed, Rejected |
| **Attendance (calendar day)** (`AttendanceStatus` enum) | Worked, No Show, Late Login, Suspended, No Shifts, Absent |
| **Attendance import row** (boolean) | Processed, Cancelled |
| **Document expiry** (derived, not stored) | No Expiry, Expired, Expiring in N days, Valid |
| **Type/category tags** (not lifecycle status, same visual language) | Vehicle Owner Type, Vehicle Registered On, Passport Request Type, Helpdesk Type, HR task category, SIM assignment |

**~30 distinct lifecycle-status values, across 9 independent domains, plus 6 adjacent "tag" vocabularies** that currently borrow the same badge look without being states at all.

## 3. Inconsistencies found

### 3.1 The same word gets different colors in different files

| Status word | Colors seen | Where |
|---|---|---|
| **Active** | opacity-layered `green-500/40` + `border-green-800`; hex `#DCFCE7`/`#166534`; `green-100`/`green-800`; `green-100`/`green-700` (labeled "Processed") | #1, #2, #3, #7 in §1 |
| **Suspended** | hex `#FCE7F3`/`#BE185D` (pink); `rose-50`/`rose-500`; **`purple-50`/`purple-700`** | Rider (#2), Rider detail header (#3), Attendance calendar (#9) — three different hues for the identical English word |
| **Cancelled** | hex `#F2F2F2`/`#404040` (gray); `slate-100`/`slate-700`; `gray-100`/`gray-800` w/ `border-gray-300`; **`red-100`/`red-700`** (attendance import row) | #2, #3, #8, #7 |
| **Rejected** | `rose-100`/`rose-800` w/ `border-current`; `red-100`/`red-800` w/ `border-red-300`; hex `#F7E8EC`/`#7B1E3A` | #4, #8, #6 |
| **Approved** | `emerald-100`/`emerald-800` w/ `border-current`; `green-100`/`green-800` w/ `border-green-300` | #4, #8 |
| **Onboarding** | hex `#E8D5F2`/`#6B21A8` (purple); `indigo-100`/`indigo-700` | #2 vs #3 — **the Rider grid and the Rider's own detail page header disagree on the color of the Rider's own status** |
| **"Open"/"In Progress"-type states** | hex `#E0FBFC`/`#3D5A80`; `emerald-100`/`emerald-800` | #6, #5 — an "ongoing" state colored green in one module (usually reserved for success) and a bespoke teal in another |

### 3.2 A likely functional bug, not just a style mismatch

`RiderStatusLabel` (the canonical label map, `enum/rider-status.ts`) spells the value **"Free ID"**. `RiderStatusBadge`'s color map (`components/grid/rider-status.tsx`) keys on **`"Free Id"`** (different casing). The lookup (`colorMap[props.value]`) is case-sensitive, so if the grid ever receives the canonical-cased string, this status silently renders with **no background/border/color at all** (falls through to `""`). *(Flagged as inferred — confirming this requires checking the exact casing the API returns for this field, but the two files unambiguously disagree with each other regardless of which one is "right.")*

### 3.3 Same concept, four different visual recipes

- **Rendering technique:** a plain `<span className="...">{label}</span>` (11 of 14 implementations) vs. an opacity-layered two-`<div>` overlay (#1 `StatusBar`, #13 `OwnerType`) that achieves a similar look through a completely different, harder-to-maintain technique.
- **Border-radius:** `rounded-full` (majority) vs. `rounded-md` (#1, #13) vs. `rounded-lg` (#14, SIM grid) — three shapes for the same UI concept.
- **Border:** none (#3, #7, several type tags) vs. `border border-current` (#4, #5, #6, several type tags) vs. an explicit `-200`/`-300` token (#8, #9, #10) vs. a literal hex border (#2) — four different conventions for whether/how a badge has an edge.
- **Density:** `px-2 py-1 text-[12px]` (most) vs. `px-2.5 py-0.5 text-[11px] h-6` (#3, #10) vs. `px-2 py-0.5 text-xs` (#7) — badges sit at three different heights depending on which screen you're on, so a table with two badge types in adjacent columns (e.g. Rider status + a document-expiry badge) will show them at visibly different sizes.
- **Color depth:** `-50` vs `-100` background paired inconsistently with `-600`/`-700`/`-800` text, plus literal hex in two files that don't correspond to any Tailwind step at all (making them impossible to theme centrally later).

### 3.4 Non-status values riding on the status badge

`RiderStatus` (and therefore `RiderStatusBadge`'s color map) includes **Supervisor, Operational Manager, HR, Akhama Transfer** — these are roles/assignment categories, not points in a rider's lifecycle, but they're colored and rendered exactly like Active/Suspended/Terminated today. Recommend splitting these out (see §8, open question).

### 3.5 One thing already done right — worth keeping

`utils/expiry.ts` (`getExpiryBadge`/`getExpirySeverity`) is the **one** place in the app that already centralizes status→color logic behind a shared function, reused by the Documents tab and two Rider Dashboard cards (#10 in §1). It's proof the pattern works here; it just needs to be generalized past documents and brought in line with the new token set (§5).

## 4. Proposed semantic grouping

Every status above collapses into **five semantic tones**. A status's tone is chosen by what it *means* for the user reading it — not by which module it happens to live in:

| Tone | Meaning | Statuses assigned |
|---|---|---|
| **Success** (green) | Final/positive, healthy, nothing to do | Active, Approved, Completed, Processed, Worked, Valid, Logged In, Supervisor Approved |
| **Info** (blue) | Ongoing, in-flow, currently being worked | In Progress, Onboarding, Visa Process, Local Transfer, Passport Received, Collected By Rider, Open, Reopened |
| **Warning** (amber) | Needs attention, reversible, not yet resolved | Pending Review, On Hold, Passport Requested, Waiting, Suspended, Vacation, Vacation Overdue, Late Login, Expiring soon |
| **Danger** (red) | Failure, final-negative, blocked | Rejected, Terminated, Failed, Expired, No Show |
| **Neutral** (gray) | Closed-but-not-a-failure, off, not applicable | Inactive, Logged Out, Cancelled, Closed, No Shifts, No Expiry, Draft, Free ID |

Two deliberate calls worth flagging (see §8 for the open questions these raise):

- **"Suspended" → Warning, not Danger.** It's reversible/administrative (an account paused, not terminated), consistent across Rider status and Attendance — today it's inconsistently pink, rose, *and* purple; none of those three is "danger red" either, so this isn't a big a leap from any of them.
- **"Cancelled" → Neutral, not Danger.** A cancelled record is a voluntary/administrative stop, not a failure — most of today's implementations already agree (gray/slate); the one outlier (attendance import row, red) is the one that should move.
- **Rider's four process stages (Onboarding, Visa Process, Local Transfer) → all one Info blue**, not four separate hues. Today each has its own color, which lets someone visually distinguish "which stage" at a glance without reading the label — the tradeoff of unifying them is that this glanceability is traded for consistency. Flagged as an open question in §8 rather than decided unilaterally.

## 5. Standardized badge design

| Property | Standard | Rationale |
|---|---|---|
| **Background** | `{tone}-100` | One consistent depth across all five tones, better contrast than `-50`, softer than literal hex |
| **Text** | `{tone}-700` | One consistent depth (today's implementations inconsistently mix `-600`/`-700`/`-800`) |
| **Border** | `{tone}-200`, always present | A hairline border keeps the badge legible on any surface (striped table rows, colored cards) without the visual weight of a `-300` border or a literal-color border; also gives every badge a shape when copy/pasted onto a non-white background |
| **Border-radius** | `rounded-full` (pill) | Already the majority convention; a badge should read as "a badge," not a button/tag rectangle |
| **Font size** | `text-[11px]` | Matches the two implementations already tuned for table-row density (#3, #10) |
| **Font weight** | `font-semibold` | Slightly bolder than the current majority `font-medium` — improves legibility at 11px |
| **Padding** | `px-2.5` horizontal, no separate vertical padding — height is fixed instead (see below) | Matches #3/#10 |
| **Height** | Fixed `h-6` (24px), `inline-flex items-center` | Guarantees every badge is the same height regardless of label length or descenders, so a row mixing two badge types (e.g. Rider status + document expiry) lines up — today's mix of `py-1`/`py-0.5`/no-vertical-padding does not |
| **Icon** | None by default | Keeps badges minimal per the "neat, minimal" requirement; reserved for a future `leadingIcon` prop on the shared component if a specific screen needs one (e.g. a small dot for "live" states) — not needed to solve the audited inconsistencies |
| **Table/card spacing** | Vertically centered in the cell/row; no badge-specific margin — the surrounding grid/card padding governs spacing | Avoids re-litigating spacing per screen |

Resulting canonical class string (all five tones share every class except the color trio):

```
inline-flex h-6 items-center whitespace-nowrap rounded-full border px-2.5 text-[11px] font-semibold leading-none
```

## 6. Status → style mapping (design tokens)

```ts
// src/app/constants/status-tones.ts
export type StatusTone = "success" | "info" | "warning" | "danger" | "neutral";

export const STATUS_TONE_CLASSES: Record<StatusTone, string> = {
  success: "bg-green-100  text-green-700  border-green-200",
  info:    "bg-blue-100   text-blue-700   border-blue-200",
  warning: "bg-amber-100  text-amber-700  border-amber-200",
  danger:  "bg-red-100    text-red-700    border-red-200",
  neutral: "bg-gray-100   text-gray-600   border-gray-200",
};
```

Full status→tone table (this is the single source of truth §3.1's conflicts get resolved against):

| Status (canonical label) | Tone |
|---|---|
| Active, Approved, Completed, Processed, Worked, Valid, Logged In, Supervisor Approved | `success` |
| In Progress, Onboarding, Visa Process, Local Transfer, Passport Received, Collected By Rider, Open, Reopened | `info` |
| Pending Review, On Hold, Passport Requested, Waiting, Suspended, Vacation, Vacation Overdue, Late Login, "Expiring in Nd" | `warning` |
| Rejected, Terminated, Failed, Expired, No Show | `danger` |
| Inactive, Logged Out, Cancelled, Closed, No Shifts, No Expiry, Draft, Free ID | `neutral` |

*(Business-specific statuses not yet in the app — e.g. a future "Draft" workflow — slot into this same five-tone table by meaning, not by inventing a sixth color.)*

## 7. Shared component architecture

**Two new files, zero new dependencies:**

```ts
// src/app/constants/status-badge-config.ts
import { StatusTone } from "./status-tones";

interface StatusDef { tone: StatusTone; label?: string }

/** Statuses whose literal value is unambiguous app-wide. */
export const COMMON_STATUS_MAP: Record<string, StatusDef> = {
  Active: { tone: "success" },
  Inactive: { tone: "neutral" },
  Approved: { tone: "success" },
  Rejected: { tone: "danger" },
  Cancelled: { tone: "neutral" },
  Completed: { tone: "success" },
  Closed: { tone: "neutral" },
  Open: { tone: "info" },
  "In Progress": { tone: "info" },
  Failed: { tone: "danger" },
  Expired: { tone: "danger" },
  Suspended: { tone: "warning" },
  Terminated: { tone: "danger" },
  Draft: { tone: "neutral" },
  // ...
};

/** Overrides/extensions keyed by domain, for values that collide or need a
 *  friendlier label than the raw enum/API value (e.g. PassportRequestStatusEnum). */
export const DOMAIN_STATUS_MAP: Record<string, Record<string, StatusDef>> = {
  rider: {
    "Free Id": { tone: "neutral", label: "Free ID" }, // fixes the §3.2 casing bug at the source
    "Visa Process": { tone: "info" },
    "Local Transfer": { tone: "info" },
    Onboarding: { tone: "info" },
    Vacation: { tone: "warning" },
    "Vacation Overdue": { tone: "warning" },
  },
  leaveRequest: {
    "Pending Review": { tone: "warning" },
    "On Hold": { tone: "warning" },
    "Supervisor Approved": { tone: "success" },
  },
  passportRequest: {
    PASSPORT_REQUESTED: { tone: "warning", label: "Passport Requested" },
    PASSPORT_RECEIVED: { tone: "info", label: "Passport Received" },
    PASSPORT_COLLECTED_BY_RIDER: { tone: "info", label: "Collected By Rider" },
  },
  helpdesk: {
    OPEN: { tone: "info", label: "Open" },
  },
  task: {
    WAITING: { tone: "warning" },
  },
  attendance: {
    WORKED: { tone: "success", label: "Worked" },
    NO_SHOW: { tone: "danger", label: "No Show" },
    LATE_LOGIN: { tone: "warning", label: "Late Login" },
    NO_SHIFT: { tone: "neutral", label: "No Shifts" },
    EMPTY: { tone: "neutral", label: "Absent" },
  },
};
```

```tsx
// src/app/components/ui/status-badge.tsx
import { STATUS_TONE_CLASSES, StatusTone } from "@/app/constants/status-tones";
import { COMMON_STATUS_MAP, DOMAIN_STATUS_MAP } from "@/app/constants/status-badge-config";

interface StatusBadgeProps {
  /** Raw status value (enum member, API string, or boolean-as-string). */
  status: string;
  /** Namespaces the lookup so the same raw value can mean different things
   *  in different modules (e.g. "OPEN") without colliding. */
  domain?: keyof typeof DOMAIN_STATUS_MAP;
  /** Escape hatch for a one-off tone/label the config doesn't cover yet. */
  toneOverride?: StatusTone;
  labelOverride?: string;
  className?: string;
}

export const StatusBadge = ({
  status,
  domain,
  toneOverride,
  labelOverride,
  className = "",
}: StatusBadgeProps) => {
  const def =
    (domain && DOMAIN_STATUS_MAP[domain]?.[status]) ??
    COMMON_STATUS_MAP[status];

  const tone = toneOverride ?? def?.tone ?? "neutral";
  const label = labelOverride ?? def?.label ?? status ?? "—";

  return (
    <span
      className={`inline-flex h-6 items-center whitespace-nowrap rounded-full border px-2.5 text-[11px] font-semibold leading-none ${STATUS_TONE_CLASSES[tone]} ${className}`}
    >
      {label}
    </span>
  );
};
```

A boolean convenience wrapper covers `StatusBar`/`LogStatusBadge`-style usage without a separate component:

```tsx
<StatusBadge status={isActive ? "Active" : "Inactive"} />
<StatusBadge status={isLoggedIn ? "Logged In" : "Logged Out"} />
```

AG Grid cell renderers become one-line adapters, e.g. replacing all of `rider-status.tsx`:

```tsx
export const RiderStatusBadge = (props: ICellRendererParams) => (
  <StatusBadge status={props.value} domain="rider" />
);
```

The "days open" SLA badges (#11) and the type/category tags (#12, #13) are **not** statuses semantically, but the doc's requirement to avoid "unnecessary/repetitive colors" applies to them too — recommend a sibling `<Tag tone="..." />` component reusing the exact same `STATUS_TONE_CLASSES`, so a screen that shows a status badge next to a type tag doesn't introduce a fifteenth color palette by accident.

## 8. Open questions / assumptions

1. **Rider process-stage colors (Onboarding/Visa Process/Local Transfer → all Info blue).** Today each has a unique hue, which may be a deliberate "which stage am I looking at" scan aid on the Rider grid. Unifying them under one Info blue is the "minimal, few colors" choice, but trades away that at-a-glance distinction (labels still differ). **Needs a decision before implementing.**
2. **Role values inside `RiderStatus`** (Supervisor, Operational Manager, HR, Akhama Transfer) — assumed to be a data-modeling quirk (roles sharing the status enum/column) rather than intentional lifecycle states. Recommend they stop rendering as a colored status badge at all (plain neutral tag, or move off this component entirely) — needs product confirmation, since this document can't see whether other code depends on their current colors meaning something.
3. **"Free ID" vs `"Free Id"` casing (§3.2)** — flagged as a likely latent bug; needs confirming against the actual value the API returns for `RiderGrid.status` before relying on the fix in §7 to resolve it (if the API sends a third casing entirely, the domain-map key needs to match that instead).
4. **Helpdesk's unused `PENDING`/`REOPENED` colors** — declared in `helpdesk-status-badge.tsx` but not present in `HelpdeskStatusEnum`; assumed to be forward-looking dead code, kept in the proposed `DOMAIN_STATUS_MAP` for continuity but worth confirming they're still planned.
5. **Font-weight bump to `font-semibold`** and **height standardized to `h-6`** are this document's recommendation, not a constraint from the ask — easy to change to `font-medium`/a different height if design prefers matching the current majority exactly instead of the two outlier implementations this doc borrowed from.
6. **Dark mode** — none of the audited badges have a dark-mode variant today (the app is light-only per its global styles), so none is proposed here either.

## 9. Files/modules requiring migration

New (2 files):
- `src/app/constants/status-tones.ts`
- `src/app/constants/status-badge-config.ts`
- `src/app/components/ui/status-badge.tsx`

Migrate to consume `StatusBadge` (14 files, from §1):
1. `components/grid/status-bar.tsx`
2. `components/grid/rider-status.tsx`
3. `components/details/rider/rider-page-header.tsx` (delete its local `riderStatusColorMap`)
4. `components/grid/passport-request-status-badge.tsx`
5. `components/grid/helpdesk-status-badge.tsx`
6. `components/grid/task-status.tsx`
7. `components/grid/attendance-log-status.tsx`
8. `components/grid/leave-request-buttons.tsx`
9. `(pages)/HR/Attendance/components/attendance-status.tsx`
10. `utils/expiry.ts` + `components/file-uploads/document-tab.tsx` (fold into the same tone tokens; keep the existing severity-calculation logic as-is)
11. `components/grid/vehicle-owner-type.tsx`

Optional follow-on (sibling `Tag` component, §7, 5 files): `passport-request-type-badge.tsx`, `passport-request-days-badge.tsx`, `helpdesk-type-badge.tsx`, `helpdesk-days-badge.tsx`, `hr-tasks.tsx`, `vehicle-registered-on.tsx`, `constants/grid-props/sim-cards.tsx`.

## 10. Effort estimate

| Phase | Work | Estimate |
|---|---|---|
| 1 | Build `status-tones.ts` + `status-badge-config.ts` + `StatusBadge` component, resolve open questions in §8 | 0.5 day |
| 2 | Migrate the 11 status implementations in §9 (mostly deletion + a one-line adapter each) | 1–1.5 days incl. visual QA in each screen (Rider grid + detail header, Vehicle/Company grids, Leave Management, Passport Request, Helpdesk, HR Workflow tasks, Attendance calendar + import log, Document tab) |
| 3 (optional) | Sibling `Tag` component + migrate the 7 type/category/SLA badges | 0.5–1 day |
| **Total** | | **2–3 days** (1.5–2 without the optional phase) |

No backend/API changes are required — this is presentation-layer only; every value already arrives as a string the badge can key on.
