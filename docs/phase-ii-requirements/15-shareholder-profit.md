# 15 — Shareholder Profit Calculation (Milestone 2)

> Source: `CAG_Phase_II.docx` → *Calculation* (added via a late comment: "Added new point
> 'Calculation'")
> Modules touched: **New Shareholder/Profit module**, Partner Company (shareholders), Dashboard/
> Finance ([01](01-main-dashboard.md)).
> Related docs: [partner company](../partner-company-management.md),
> [data-model](../database-access-layer.md), [id generation](../authentication-authorization.md).

## 1. Requirement (as specified)

We have multiple companies, each with its own shareholders.

- Display **Company-wise Net Profit** on the dashboard.
- **Split net profit** between shareholders by their profit-sharing percentage.
- Provide **manual adjustments** between shareholders (amount added/deducted), e.g. Shareholder A
  transfers to Shareholder B; manual credit/debit entries.
- Maintain a **complete transaction history** for every adjustment: Date, Company, From Shareholder,
  To Shareholder (if applicable), Amount, Reason/Remarks, User who created it.
- After adjustments, display the **Final Profit Payable** per shareholder.
- Include **filters by Company** (text truncated in source: "filters by Comp…").

## 2. Impact & Changes

### UI (`CAG.Admin.UI`)
- **New Shareholder Profit page** (likely under Finance): company-wise net profit, the per-shareholder
  split, an adjustments entry form, an adjustments history table, and Final Profit Payable per
  shareholder. Company/Month/Year filters.
- **Partner Company** needs a **shareholders** management UI with profit-sharing **percentages** (the
  company currently stores only a single owner + `OwnerPercentage`
  — [data-model](../database-access-layer.md)). This likely extends the existing
  **Partners** concept ([partner-company](../partner-company-management.md)).

### API / DB (`CAG.Admin.API`)
- **Shareholders** — reuse/extend `Partner` (already per-company owners with percentages) or add a
  `Shareholder` table. `Partner` + `OwnerPercentage` is the natural fit.
- **New table** `ShareholderAdjustment` — `Id`, `CompanyId`, `FromShareholderId`, `ToShareholderId?`,
  `Amount`, `Reason`, `EntryDate`, `CreatedBy`, `CreatedAt`. An immutable ledger of transfers/credits/
  debits.
- **Net Profit source** — `Net Profit = Revenue − Payroll − Company Expenses`
  ([01](01-main-dashboard.md), [12](12-company-expenses.md)); split by shareholder percentage; apply
  adjustments; output Final Profit Payable.
- **Endpoints** `api/shareholder-profit/*` — company-wise profit, per-shareholder split + final,
  adjustments (list/add), all company-scoped.

### Cross-cutting
- **Depends on** [01](01-main-dashboard.md) + [12](12-company-expenses.md) for the Net Profit terms
  (revenue, payroll, company expenses). Cannot compute Final Payable until those exist → M2, after 12.
- Adjustments ledger reuses the **immutable audit ledger** pattern
  ([04](04-rider-expense.md), [12](12-company-expenses.md)).

## 3. Open Questions & Suggestions

### UI-side
- **Q:** Where does this live — a Finance sub-page, or a card on the main dashboard?
  💡 A dedicated Finance → Shareholder Profit page (it's detailed); the main dashboard shows only
  company-wise Net Profit ([01](01-main-dashboard.md)).
- **Q:** Adjustment entry — always shareholder-to-shareholder, or also standalone credit/debit (no
  "to")?
  💡 Support both: `ToShareholderId` nullable → a transfer when set, a manual credit/debit when null
  (the doc lists both).
- **Q:** Final Profit Payable — per month, per year, or cumulative?
  💡 Per selected period (Month/Year filter) with a running/cumulative option; default to the selected
  month.

### API / Data-side
- **Q:** Reuse `Partner` (existing per-company owner + `OwnerPercentage`) as the shareholder, or a new
  `Shareholder` table?
  💡 Extend **`Partner`** — it already models per-company owners with percentages. Add fields if
  needed rather than a parallel table.
- **Q:** Do shareholder percentages sum to 100% per company, and is that enforced?
  💡 Validate the sum ≈ 100% per company on save; warn (don't hard-block) to allow interim edits.
- **Q:** Net Profit definition — confirm it matches [01](01-main-dashboard.md)
  (`Revenue − Payroll − Company Expenses`). Are EMIs/traffic fines included?
  💡 Use the same definition as 01; pending EMI/fines are shown separately, not deducted. Confirm.
- **Q:** Are adjustments immutable, or editable/reversible?
  💡 Immutable; a correction is a new reversing entry (standard ledger practice) so history stays
  complete, as the requirement demands.
- **Q:** Should an adjustment affect **both** shareholders' Final Payable (A −amount, B +amount)?
  💡 Yes for transfers (double-entry); single-sided for standalone credit/debit. Make the direction
  explicit in the model.

### Business / Product
- **Q:** The source text is truncated ("filters by Comp…") — confirm the full filter set (Company,
  Month, Year, Shareholder?).
  💡 Company + Month + Year at minimum; add Shareholder filter for the history table.
- **Q:** Rounding rule for the percentage split (who absorbs the remainder cent)?
  💡 Round each share to 2dp; assign the rounding remainder to the largest shareholder. Confirm the
  accounting preference.
- **Q:** This is the most finance-sensitive requirement — confirm sign-off on the Net Profit formula
  and adjustment semantics before build.
  💡 Get written confirmation of the formula and double-entry behaviour; it drives real payouts.
