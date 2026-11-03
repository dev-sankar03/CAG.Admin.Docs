# Admin → Templates (upload templates)

Built 2026-11-03. One Admin page lists the file each upload screen expects, with a Download button. Admin role only (API and page).

## Where the files live

`CAG_Admin/<environment>/Templates` on the file server (`FilePath:TemplateFiles` = `Templates` in `appsettings.json`; `<environment>` = `FilePath:Environment`: QA, PROD, or Dev for local runs), one sub-folder per module. Developers place and replace the files there directly; nothing is uploaded, versioned or stored in the database. The page shows each file's own date on the server as *Last updated*.

`templates.json` in that folder gives each file its name, module, screen ("used on") and description:

```json
[{ "file": "Sales Cash/Sales cash import.xlsx", "name": "Sales cash import", "module": "Sales Cash",
   "usedOn": "Sales Cash → Import", "description": "…" }]
```

A file it does not list still shows, named after the file, with its sub-folder as the module. An entry without a file is not shown. An invalid `templates.json` is logged and the files are listed without descriptions.

## Files placed on 2026-11-03 (QA and Dev)

| File | Built from |
| --- | --- |
| Sales Cash/Sales cash import.xlsx | The client's WSLL pending-dues sheet layout (row 1 Sales / Collection groups, row 2 headers, 01-S…31-S, 01-C…31-C), no data |
| Riders/Rider expenses import.xlsx | Category, Date, Amount, Reference No, Remarks |
| Riders/Bulk expenses import.xlsx | Rider ID + the same columns |
| Client User ID/Contract expiry import.xlsx | Client User ID, Contract Expiry |

Still to be placed by the team (already described in `templates.json`): `Finance/Payroll orders import.xlsx`, `HR/Attendance import.xlsx`, `HR/Attendance order list import.xlsx`, `HR/Shift report import.csv` — these are the client systems' own exports, best taken from a real current file with the data removed.

## Changing a template

Replace the file on the server keeping its name (or add one in its module's folder and its entry in `templates.json`). No release is needed unless the importer's columns change, in which case the template is replaced in the same release.

## API

`GET api/templates` (list: folder listing joined with `templates.json`) and `GET api/templates/download?file=<path inside the folder>` (only a file the folder holds; `Cache-Control: no-store`). `TemplateService`, `FileService.ListFilesAsync` / `ResolveFolder`.
