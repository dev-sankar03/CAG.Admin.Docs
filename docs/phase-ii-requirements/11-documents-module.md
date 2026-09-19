# 11 — Documents Module: UI, Optional Expiry, View, Multi-file (Milestone 1)

> Source: `CAG_Phase_II.docx` → *Documents Module (Milestone 1)*
> Modules touched: Documents (`api/document`), file-upload UI.
> Related docs: [documents module](../document-management.md),
> [upload flow](../document-management.md),
> [expiry](../document-management.md),
> [known-behaviours](../known-behaviours.md).

## 1. Requirement (as specified)

- Update the **UI** per the shared screenshot.
- **Remove the mandatory Expiry Date** requirement (even Selfie documents currently demand an
  expiry).
- **Reduce spacing** between fields to minimise scrolling.
- Add a **View** option to open/view the document on the same page.
- Allow uploading **2–3 images/files under the same document type** if required.

## 2. Impact & Changes

### UI (`CAG.Admin.UI`)
- **Uploader** (`components/file-uploads/documents-uploader.tsx`, `document-tab.tsx`,
  `document-card.tsx`) — restyle per the screenshot, tighten spacing, and:
  - drop the client-side "expiry required" rule for non-expiring types;
  - add an inline **View** (open the file in-page — the API already streams inline with
    `Content-Disposition: inline`, [upload flow](../document-management.md));
  - allow **multiple files per document type** in one add action.
- ⚠️ The current uploader has a **null-guard bug** when copying an existing expiry for a type
  ([known-behaviours](../known-behaviours.md)) — fix it as part of this
  restyle.

### API / DB (`CAG.Admin.API`)
- **Mandatory-expiry** is driven by `DocumentType.isMandatory`
  ([documents](../document-management.md)); making expiry optional means the
  UI stops forcing it and the API accepts a null `ExpiryDate`. Confirm no server-side rule rejects
  null expiry. The upload model's `ExpiryDate` is already nullable
  ([upload flow](../document-management.md)).
- **Multi-file per type** — the upload endpoint already accepts a **list** of files
  (`FileUploadRequestModel.Files`), so this is largely a UI change; verify the display groups
  multiple docs under one type.

### Cross-cutting
- ⚠️ This module is where the **rider-onboarding document-save bug** ([14 #4](14-misc-changes.md))
  lives — documents uploaded during onboarding aren't saved and a false "Failed" popup shows. The
  root cause (non-transactional post-create upload) is documented in
  [known-behaviours](../known-behaviours.md).
  Fix 14#4 together with this module.
- Making expiry optional interacts with **compliance/expiry alerts**
  ([expiry](../document-management.md)) — a doc with no expiry simply never
  appears in expiring lists (correct), but confirm mandatory *types* (passport, licence) still
  require it.

## 3. Open Questions & Suggestions

### UI-side
- **Q:** Should expiry be optional for **all** types, or only non-expiring ones (Selfie), keeping it
  required for passport/licence/civil-id?
  💡 Keep it driven by `DocumentType.isMandatory` per type — mark Selfie (and similar) non-mandatory,
  keep passport/licence mandatory. This is the doc's actual intent ("even Selfie asks for expiry").
- **Q:** "View on the same page" — inline preview (PDF/image viewer) or open in a side panel/modal?
  💡 In-page modal/side panel using the streamed inline file; images render directly, PDFs in an
  `<iframe>`/embed. The API already sets `inline` disposition.
- **Q:** Multi-file per type — how are the 2–3 files displayed and individually deletable?
  💡 Group by type; each file a card with its own View/Delete. The `Document` rows are already
  independent, so per-file delete works today.
- **Q:** Match the shared screenshot — grid of cards, or a compact list?
  💡 Compact card grid with reduced padding (the doc asks specifically to cut scrolling); confirm
  against the screenshot.

### API / Data-side
- **Q:** Is there any **server-side** enforcement of mandatory expiry to remove, or is it UI-only
  today?
  💡 It's UI-driven via `isMandatory`; the API already accepts null `ExpiryDate`. Just ensure no
  validator rejects it. Verify.
- **Q:** For multi-file, should all files under one type **share one expiry** (via `DocumentTypeExpiry`,
  which is per-type-per-source) or have per-file expiries?
  💡 Per-type expiry (the current `DocumentTypeExpiry` model is per `(Source, SourceId,
  DocumentTypeId)`), so multiple files of a type share one expiry — matches the data model. Confirm
  that's acceptable.
- **Q:** Should the false-"Failed" onboarding popup fix ([14 #4](14-misc-changes.md)) be part of this
  ticket?
  💡 Yes — bundle it; same code area, and it's the highest-visibility document bug.

### Business / Product
- **Q:** Provide the reference screenshot for the new layout.
  💡 Client to share; we match spacing/order.
- **Q:** Max files per type — the doc says "2 or 3". Hard cap or soft?
  💡 Soft cap of ~5 with a note; don't hard-block at 3 unless required.
