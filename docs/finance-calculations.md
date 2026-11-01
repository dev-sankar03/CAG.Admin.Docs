# Finance → Calculations (shareholder profit split)

Milestone 2 requirement #35, built 2026-11-01. Page `/Finance/Calculations` (module CAG_FINANCE).

## What it shows

One row per company and month (of the chosen year, or one month), up to the current month:

    Net amount = Net profit + Additions − Deductions + Carried in

- **Net profit** — the Finance dashboard's Net Profit for that company and month (revenue − payroll − company expenses; same query, `DashboardRepository.GetCompanyMonthFinanceAsync`).
- **Additions / Deductions** — entries with date, description, amount and type; an entry counts in the month of its date.
- **Carried in** — the net amount of the earlier months that are not processed. Each unprocessed month carries its whole net amount into the next, so an amount is only ever counted once, in the latest month.
- **Status** — *Not Processed*, *Processed*, or *Settled in &lt;month&gt;* (not processed itself, but its amount was paid in a later month that was processed).

Clicking a row opens the detail: how the net amount is made up, which months it carries, the split among the shareholders, the additions / deductions, Mark processed / Reopen and the history.

## Shareholders

The partner company's owners (Partner Company → Partners) with their registered percentage. Each gets `net amount × % / 100` (KWD, 3 decimals). If the percentages add up to less than 100 %, the rest is shown as *Not assigned to a shareholder*.

## Processed and reopen

- *Mark processed* (Finance **Edit** permission) once the share is paid out. The month's figures and the split are **stored** (`ProfitSharePeriod`, `ProfitShareSplit`) and stay as they were even if revenue or expenses change later. Nothing is carried to the next month, and the unprocessed months before it become *Settled*.
- Only a month after the company's last processed month can be processed (an earlier one is already settled), and not a future month.
- *Reopen* is **Admin only**, and only for the company's latest processed month. The month goes back to Not Processed and carries forward again.
- Additions / deductions can change only in a Not Processed month (not in a processed or settled one).

## History and records

Nothing is hard-deleted: deleting an adjustment sets `isActive = 0`. Every add / change / delete / process / reopen is written to `ProfitShareHistory` (who, when, what, amount) and shown in the detail.

## Export

*Export* downloads `Calculations_<year>[-<month>].xlsx` with three sheets: Calculations (the rows), Shareholders (each month's split — stored for processed months, from today's partners otherwise) and Adjustments. The Company filter on the page narrows the export.

## API and data

`api/finance-calculations` — `GET ?year&month` (rows), `GET detail?companyId&month`, `GET export?year&month&companyIds`, `POST adjustments`, `PUT adjustments/{id}`, `DELETE adjustments/{id}`, `PUT status` (`{ companyId, month, processed, remarks }`). `FinanceCalculationService` works the carry-forward out on each read, from the first month the company has any finance data (at most 60 months back); `ProfitShareRepository`. Script `2026-11-01_FinanceCalculations.sql` (runbook #47).

## Worked example (Dev, AMK, 2026-11-01)

| Step | Oct | Nov |
|---|---|---|
| Start | Net profit −64.090 → net −64.090, Not Processed | carried in −64.090 → net −64.090 |
| Add a 100.500 addition and a 20.000 deduction dated in October | −64.090 + 100.500 − 20.000 = **16.410** | carried in 16.410 |
| Mark October processed | Processed, 16.410 stored; split: 50 % owner 8.205, not assigned 8.205; Aug / Sep → Settled in Oct | carried in 0 |
| Reopen October (Admin), mark November processed | Settled in Nov | Processed, with 16.410 carried in |

Editing an October entry while October is processed is refused ("An Admin has to reopen it…"), and so is processing or editing a settled month. The test rows were removed from Dev afterwards.
