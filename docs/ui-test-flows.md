# UI Test Flows - CAG Admin UI

**Date**: May 18, 2026  
**Scope**: Testing ClientRiderConfig synchronization changes in API

---

## 📍 UI Pages Affected

| Page | Path | Purpose | Modified API |
|------|------|---------|--------------|
| **Client User ID Management** | `/Rider/Client-User-Id` | Manage client user IDs and rider assignments | `PUT /api/client-user-id` ⭐ |
| **Payroll Import** | `/Finance/Payroll` | Import rider orders via Excel | `POST /api/riderorder/import` ⭐ |

---

# 🧪 TEST FLOWS

## TEST FLOW 1: Update Client User ID with New Rider

**Page**: `/Rider/Client-User-Id`  
**Component**: `Client-User-Id/index.tsx`  
**API Modified**: `PUT /api/client-user-id` ⭐ PRIMARY

### User Actions:

1. **Navigate to Client User ID page**
   - Go to `/Rider/Client-User-Id`
   - Wait for grid to load (showing all client user IDs)

2. **Locate a client user ID in the grid**
   - Find row with current RiderId: e.g., "RD261011"
   - Verify data loads correctly

3. **Open Edit Modal**
   - Click Edit button on the row OR click on the row to open details
   - Modal should display:
     - ClientUserId (read-only)
     - Current RiderId dropdown (e.g., "RD261011")
     - Contract Expiry date picker
     - Current rider info

4. **Change RiderId to Different Rider**
   - Click RiderId dropdown
   - Select a new rider from list (e.g., "RD261089")
   - Modal should show new rider details

5. **Update Contract Expiry**
   - Change the Contract Expiry date if needed
   - Click "Save" or "Update" button

6. **Verify Success Response**
   - Toast notification shows: "Client User ID updated successfully"
   - Modal closes
   - Grid refreshes/updates

### Expected Results:

✅ **UI State**:
- Row in grid shows new RiderId: "RD261089"
- Contract Expiry date updated

✅ **Database State (Backend)** ⭐ CRITICAL:
- `ClientUserId.RiderId` = "RD261089" ✅
- `ClientRiderConfig` with old RiderId (RD261011):
  - `IsActive` = false
  - `EndDate` = current timestamp
- `ClientRiderConfig` with new RiderId (RD261089):
  - `IsActive` = true
  - `StartDate` = current timestamp

### Test Cases:

| # | Scenario | Expected Behavior |
|---|----------|------------------|
| 1.1 | Change RiderId from RD261011 → RD261089 | Both tables sync, old config ended, new config created |
| 1.2 | Update same RiderId again | No unnecessary ClientRiderConfig records |
| 1.3 | Clear RiderId (set to null/empty) | Old config ended, no new config created |
| 1.4 | Update ContractExpiry only (same RiderId) | Only ClientUserId updated, no ClientRiderConfig changes |
| 1.5 | Invalid rider selection | Validation error shown |
| 1.6 | Past contract expiry date | Warning or validation error |

---

## TEST FLOW 2: Import Rider Orders with ClientRiderConfig Sync

**Page**: `/Finance/Payroll`  
**Component**: `Payroll/components/orders-import.tsx`  
**API Modified**: `POST /api/riderorder/import` ⭐ PRIMARY

### User Actions:

1. **Navigate to Payroll page**
   - Go to `/Finance/Payroll`
   - See tabbed interface: "Payroll" | "Import Logs" | "Summary"
   - Verify current month is pre-selected

2. **Click Import Button**
   - Click "Import Orders" or similar button
   - Modal opens: `PayrollImport` component

3. **Select Company** (Required)
   - Click Company dropdown
   - Select a company (e.g., "ABC Transport")
   - Verify company is selected

4. **Select Order Month** (Optional)
   - Date picker shows current month (MM/YYYY format)
   - Can modify to different month if needed
   - Default is correct month for payroll

5. **Upload Excel File**
   - Click file drop zone OR
   - Drag & drop Excel file (.xlsx, .xls)
   - Select file from file browser

   **File Validation**:
   - ✅ File type must be `.xlsx` or `.xls`
   - ✅ File size must be < 10MB
   - ✅ Show error if invalid: "Please select a valid Excel file"

6. **File Processing**
   - Show uploading indicator (spinner/progress)
   - Status message updates during upload

7. **Import Response Handling**

   **Success Case** ✅:
   - Green checkmark icon
   - Message: "Rider orders imported successfully"
   - Show count: "X orders imported"
   - Button: "View Details" or "Close"

   **Error Case** ❌:
   - Red warning icon
   - Error message with details:
     - "Row 5: No active ClientRiderConfig found for ClientUserId 101"
     - "Row 8: RiderId mismatch... (using config value)"
     - "X errors, Y rows skipped"
   - Show import log link

8. **View Import Logs** (if errors)
   - Click "Import Logs" tab
   - See upload history with statuses
   - Can view detailed error messages

9. **Close Modal**
   - Click "Done" or "X" button
   - Return to Payroll page
   - Grid updates to show newly imported orders

### Expected Results:

✅ **UI State**:
- Import modal shows success message
- Payroll grid updated with new rider orders
- Status can be viewed in Import Logs

✅ **Database State (Backend)** ⭐ CRITICAL:
- Rider orders created with **correct RiderId** from ClientRiderConfig (not ClientUserId)
  - Order.RiderId = ClientRiderConfig.RiderId (e.g., "RD261089")
  - NOT Order.RiderId = ClientUserId.RiderId (old broken behavior)
- Orders properly grouped by rider and batch

### Test Cases:

| # | Scenario | Expected Behavior |
|---|----------|------------------|
| 2.1 | Valid import with matching ClientRiderConfig | All orders imported, correct RiderId used |
| 2.2 | File with row missing ClientRiderConfig | Row rejected, error logged, other rows imported |
| 2.3 | RiderId mismatch (ClientUserId ≠ ClientRiderConfig) | Logs mismatch warning, uses ClientRiderConfig value |
| 2.4 | File size > 10MB | Show error: "File size must be less than 10MB" |
| 2.5 | Invalid file type (CSV, PDF, etc.) | Show error: "Please select a valid Excel file" |
| 2.6 | Duplicate order rows in file | Handle based on business logic (merge/skip) |
| 2.7 | Invalid company ID | Show error: "Invalid Company ID" |
| 2.8 | Empty or corrupted Excel file | Show error with details |

---

## TEST FLOW 3: Start Permanent Rider Assignment

**Page**: `/Rider/Client-User-Id`  
**Component**: `Client-User-Id/index.tsx`  
**API**: `PUT /api/client-user-id/update-rider-assignment`

### User Actions:

1. **Open Client User ID page**
   - Navigate to `/Rider/Client-User-Id`

2. **Find a Client User ID without active permanent rider**
   - Look for row with empty "Permanent Rider" column OR
   - Row with ended permanent rider

3. **Click "Start Permanent Rider" button**
   - Action menu shows: "Start" option
   - Click "Start"

4. **Confirm Assignment**
   - Modal appears: Select Rider and Date
   - Choose rider from dropdown (e.g., "RD261089")
   - Set Start Date (defaults to today)
   - Click "Confirm" or "Start"

5. **Verify Success**
   - Toast: "Permanent rider assignment started"
   - Grid row updates:
     - "Permanent Rider" column shows selected rider
     - Status shows "Active"

### Expected Results:

✅ **UI State**:
- Grid row shows new permanent rider
- Rider status changed to Active (if applicable)

✅ **Database State**:
- `ClientRiderConfig` created with new assignment
- `ClientUserId.RiderId` = selected RiderId
- `ClientUserId.IsAssigned` = true

---

## TEST FLOW 4: End Permanent Rider Assignment

**Page**: `/Rider/Client-User-Id`  
**API**: `PUT /api/client-user-id/update-rider-assignment`

### User Actions:

1. **Open Client User ID page**
   - Navigate to `/Rider/Client-User-Id`

2. **Find Client User ID with active permanent rider**
   - Look for row with "Permanent Rider" populated
   - Click row to expand or find "End" button

3. **Click "End Permanent Rider" button**
   - Action menu shows: "End" option
   - Click "End"

4. **Confirm End Date**
   - Modal shows current rider and date picker
   - Set End Date (defaults to today)
   - Click "Confirm" or "End"

5. **Verify Success**
   - Toast: "Permanent rider assignment ended"
   - Grid updates:
     - "Permanent Rider" column becomes empty
     - Status changes to "Inactive" or "Free"

### Expected Results:

✅ **Database State**:
- Old `ClientRiderConfig` marked inactive with EndDate
- `ClientUserId.RiderId` cleared
- `ClientUserId.IsAssigned` = false

---

## TEST FLOW 5: Start Temporary Rider Assignment

**Page**: `/Rider/Client-User-Id`  
**API**: `PUT /api/client-user-id/update-rider-assignment`

### User Actions:

1. **Navigate to Client User ID page**
   - Go to `/Rider/Client-User-Id`

2. **Find Client User ID without temp rider**
   - Look for row with empty "Temporary Rider" column

3. **Click "Start Temporary Rider"**
   - Action menu or modal for temporary rider
   - Click "Start"

4. **Select Rider and Date**
   - Choose different rider from permanent (e.g., "RD261045")
   - Set Start Date
   - Click "Start"

5. **Verify Success**
   - Toast: "Temporary rider assignment started"
   - Grid shows:
     - "Permanent Rider" unchanged
     - "Temporary Rider" now shows new rider

### Expected Results:

✅ **Database State**:
- `ClientRiderConfig` created for temp assignment
- `ClientUserId.TempRiderId` = selected RiderId
- Separate record from permanent assignment

---

## TEST FLOW 6: End Temporary Rider Assignment

**Page**: `/Rider/Client-User-Id`  
**API**: `PUT /api/client-user-id/update-rider-assignment`

### User Actions:

1. **Navigate to Client User ID page**

2. **Find Client User ID with active temp rider**
   - "Temporary Rider" column populated

3. **Click "End Temporary Rider"**

4. **Confirm End Date**

5. **Verify Success**
   - "Temporary Rider" column becomes empty
   - Permanent rider (if any) remains

---

## TEST FLOW 7: Create New Client User ID with Rider Assignment

**Page**: `/Rider/Client-User-Id`  
**API**: `POST /api/client-user-id`

### User Actions:

1. **Navigate to Client User ID page**

2. **Click "Add New" or "+" button**
   - Modal opens: Create new assignment

3. **Fill in Form**:
   - Select Client User ID (dropdown from available IDs)
   - Select Client (company/organization)
   - Select Permanent Rider
   - Set Start Date
   - Set Contract Expiry
   - Optional: Set End Date (for temporary assignment)

4. **Click "Create" or "Save"**
   - Success toast appears
   - Grid adds new row

5. **Verify New Row**
   - Grid shows new client user ID
   - Rider assigned and active
   - Dates correct

### Expected Results:

✅ **Database State**:
- `ClientUserId` record created
- `ClientRiderConfig` record created
- Both linked correctly

---

## TEST FLOW 8: Delete Client User ID with Active Assignments

**Page**: `/Rider/Client-User-Id`  
**API**: `DELETE /api/client-user-id/{id}`

### User Actions:

1. **Navigate to Client User ID page**

2. **Find Client User ID with active assignments**

3. **Click "Delete" button**
   - Confirmation modal appears:
     - "This will end all active rider assignments. Continue?"

4. **Click "Confirm Delete"**
   - Toast: "Client User ID deleted successfully"
   - Row removed from grid

### Expected Results:

✅ **Database State**:
- `ClientUserIdModel` deleted
- All active `ClientRiderConfig` records marked inactive
- Cleanup completed

---

# 🔍 DATA VERIFICATION CHECKLIST

After each test flow, verify the following **across UI and API**:

### Scenario: Update RiderId from RD261011 → RD261089

**Check in UI Grid**:
- [ ] ClientUserId row shows new RiderId: RD261089
- [ ] Contract Expiry date updated
- [ ] No duplicate rows

**Check in API/Database**:
- [ ] `SELECT ClientUserId.RiderId WHERE ClientUserId = 101` → "RD261089" ✅
- [ ] `SELECT ClientRiderConfig WHERE ClientUserId = 101 AND RiderId = 'RD261011'` → IsActive = false, EndDate = now ✅
- [ ] `SELECT ClientRiderConfig WHERE ClientUserId = 101 AND RiderId = 'RD261089'` → IsActive = true, StartDate = now ✅

**Check in Import Flow**:
- [ ] Orders imported use RiderId = 'RD261089' (from ClientRiderConfig)
- [ ] NOT 'RD261011' (old broken value)

### Scenario: Import Rider Orders

**Check in UI**:
- [ ] Import modal shows success message
- [ ] Order count displayed
- [ ] No error messages (unless expected)

**Check in Database**:
- [ ] `SELECT RiderId FROM RiderOrder WHERE ClientUserId = 101` → "RD261089" ✅
- [ ] Orders grouped by correct RiderId
- [ ] Historical data matches ClientRiderConfig

---

# 📋 TEST EXECUTION MATRIX

| Flow | Priority | Critical | API Tested | Status |
|------|----------|----------|-----------|--------|
| 1: Update Client User ID | 🔴 P0 | YES | PUT /api/client-user-id | [ ] |
| 2: Import Rider Orders | 🔴 P0 | YES | POST /api/riderorder/import | [ ] |
| 3: Start Permanent | 🟡 P1 | MEDIUM | PUT /api/client-user-id/update-rider-assignment | [ ] |
| 4: End Permanent | 🟡 P1 | MEDIUM | PUT /api/client-user-id/update-rider-assignment | [ ] |
| 5: Start Temporary | 🟡 P1 | MEDIUM | PUT /api/client-user-id/update-rider-assignment | [ ] |
| 6: End Temporary | 🟡 P1 | MEDIUM | PUT /api/client-user-id/update-rider-assignment | [ ] |
| 7: Create New Assignment | 🟢 P2 | LOW | POST /api/client-user-id | [ ] |
| 8: Delete Assignment | 🟢 P2 | LOW | DELETE /api/client-user-id/{id} | [ ] |

---

# ⚠️ CRITICAL VERIFICATION POINTS

### Must Verify After Each Test:

1. **Mismatch Detection** ⭐
   - Import logs show mismatch warnings (if applicable)
   - System uses ClientRiderConfig value (not ClientUserId)

2. **Data Consistency** ⭐
   - Both tables stay synchronized
   - No orphaned records

3. **Historical Tracking** ⭐
   - Old records marked inactive (not deleted)
   - Audit trail preserved (CreatedBy, UpdatedBy, timestamps)

4. **Edge Cases** ⭐
   - Null RiderId handled correctly
   - Same RiderId updates don't create duplicates
   - Missing ClientRiderConfig handled gracefully

---

# 🚀 Test Execution Tips

1. **Clear UI Cache**: Hard refresh browser (Ctrl+Shift+R) between tests
2. **Check Network Tab**: Monitor API calls in DevTools to verify endpoints
3. **Database Queries**: Run verification queries before/after each test
4. **Logs**: Check server logs for any errors during import
5. **Toast Notifications**: Note all success/error messages
6. **Grid Updates**: Verify grid refreshes after each action
7. **Modal Validation**: Check all field validations work correctly

---

## Test Environment

- **UI URL**: `http://localhost:3000` (or staging URL)
- **API URL**: Check `.env` file for API base URL
- **Database**: Accessible for verification queries
- **Test Data**: Use test company and rider IDs (not production)

---

**Status**: Ready for testing  
**Last Updated**: May 18, 2026
