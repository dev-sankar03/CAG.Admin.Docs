# 05 — Complaint Section (Milestone 1)

> Source: `CAG_Phase_II.docx` → *Complaint Section (Milestone 1)*
> Modules touched: Rider detail, (possibly) Helpdesk, a new comments/notes store.
> Related docs: [helpdesk](../implementation-impact-analysis.md),
> [leave-request comments](../implementation-impact-analysis.md) (an existing comment pattern),
> [cross-cutting audit](../authentication-authorization.md).

## 1. Requirement (as specified)

- **All departments** should be able to **add comments on the rider**.

(One line in the source — deliberately open. The questions below exist to turn it into a spec.)

## 2. Impact & Changes

### UI (`CAG.Admin.UI`)
- A **Comments/Complaints panel** on the rider detail page (a section in the
  [08](08-rider-more-details.md) scrolling layout, or a dedicated tab): a timeline of comments with
  author, department, timestamp, and an "Add comment" box.

### API / DB (`CAG.Admin.API`)
- **New table** `RiderComment` (or `RiderComplaint`): `Id`, `RiderId`, `Comment`, `Department`/`Category`,
  `CreatedBy`, `CreatedAt` (+ `UpdatedBy/At` if edits allowed). Follows the platform audit convention
  ([data-model](../database-access-layer.md)).
- **New endpoints** `api/rider/{riderId}/comments` (GET list, POST add) — or a standalone
  `api/rider-comment` controller/service/repository trio, matching the existing pattern.
- **Reuse candidate:** `LeaveRequestComment` already implements a rider-adjacent comment thread
  (`LeaveRequestCommentService`/`Repository`, `api/leaverequest/comment/*`) — mirror its shape rather
  than inventing a new one.

### Cross-cutting
- "All departments" = every authenticated role can **add**; consider whether all can **view** and
  whether any can **delete** (ties to the role-gating work in [14 #7](14-misc-changes.md)).
- Company scoping still applies — a user should only comment on riders within their `CompanyIds`.

## 3. Open Questions & Suggestions

### UI-side
- **Q:** Where does the panel live — a tab, or a section in the new scrolling rider layout
  ([08](08-rider-more-details.md))?
  💡 A section in the scrolling layout titled "Complaints / Comments", pinned near the top so it's
  visible without hunting.
- **Q:** Threaded replies, or a flat comment list?
  💡 Flat, newest-first, is enough for "add comments on the rider". `LeaveRequestComment` is flat —
  reuse that UX.
- **Q:** Should each comment show the author's **department**, and is department derived from role or
  chosen at post time?
  💡 Derive department from the author's role automatically; don't ask the user to pick it.
- **Q:** Attachments on a complaint (photo of an issue)?
  💡 Optional single attachment via `FileService`; confirm need before building.

### API / Data-side
- **Q:** New dedicated table/endpoints, or extend an existing comment mechanism?
  💡 New `RiderComment` table + `api/rider/{riderId}/comments`, **cloned from** the
  `LeaveRequestComment` implementation for consistency and speed.
- **Q:** Are comments editable/deletable, and by whom?
  💡 Immutable by default (append-only audit trail of complaints); allow delete only by Admin/Ops.
  This keeps it defensible as a record.
- **Q:** Is "complaint" a distinct type from a general "comment" (severity, status, resolution)?
  💡 Confirm — if complaints need a lifecycle (Open/Resolved), this becomes closer to a lightweight
  Helpdesk ticket scoped to a rider. Start with plain comments; add status only if required.

### Business / Product
- **Q:** Who can **view** rider complaints — all departments, or only HR/Ops?
  💡 All authenticated users within company scope can view; only Admin/Ops can delete. Confirm any
  confidentiality constraint.
- **Q:** Does a complaint need to notify anyone (HR, supervisor)?
  💡 Out of scope unless stated; note as a possible follow-up (no notification infra exists today).
