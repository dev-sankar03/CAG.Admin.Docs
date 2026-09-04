-- =============================================================================
-- CAG Admin — MySQL Schema Snapshot
-- =============================================================================
-- Source: verbatim copy of CAG.Admin.DB/CAG_Schema.sql (the authoritative
-- schema export maintained alongside this repository).
--
-- Provenance and caveats (see docs/architecture-overview.md, "Database
-- architecture", for the full discussion):
--   - There is no migration framework in this codebase. This file is a
--     manually re-exported point-in-time snapshot, not a source of truth
--     enforced by tooling. Schema changes are applied to the live MySQL
--     server by hand; this file must be re-exported after each change to
--     stay current.
--   - This snapshot is dated 2026-06-21 (per its own header comments below).
--     A separate CSV catalog export in CAG.Admin.DB/ (Tables.csv,
--     Unique_Constraints.csv, etc.) is dated roughly ten weeks later
--     (2026-09-03/04) and disagrees with this file in at least one
--     confirmed place: RiderOrder's unique constraint appears here as
--     uq_rider_company_month_batch_vehicle (riderId, companyId, orderMonth,
--     batchNo, vehicleType), but the CSV catalog lists it as the differently
--     named, three-column uq_rider_month_batch (riderId, batchNo,
--     orderMonth). Treat any single export — this one included — as a
--     snapshot to verify against the live server, not as ground truth.
--   - A leftover table named `temp` (a simple log table, unrelated to any
--     application feature) appears in this dump; it is not part of the
--     documented data model in docs/*.md and was not present in the later
--     CSV table catalog, suggesting it was dropped between exports.
--   - Two tables' PassportRequest.comments and Helpdesk.comments carry a
--     redundant, duplicated json_valid() CHECK constraint declaration in the
--     live schema (visible in this file as a single CHECK per column, but
--     confirmed doubled in the CSV constraint catalog) — cosmetic, not
--     functionally significant.
--   - Two generated columns are worth knowing about before reading queries
--     elsewhere in this documentation set: Payroll.netPay is
--     GENERATED ALWAYS AS (grossEarnings - totalExpenses) STORED — it does
--     NOT subtract vehicle EMI, unlike the fuller net-pay formula computed
--     transiently inside sp_process_rider_payroll (see
--     docs/payroll-management.md). LeaveRequest.totalDays is a correct,
--     unremarkable GENERATED column derived from startDate/endDate.
--
-- Stored procedures (sp_generate_company_payroll, sp_process_rider_payroll)
-- are NOT included in this file — they are not part of the DDL dump this
-- file was copied from. Their full bodies are transcribed and analyzed in
-- docs/payroll-management.md, sourced from CAG.Admin.DB/Stored_Procedures.csv.
-- =============================================================================

-- CAG_Admin_Dev.AttendanceUploadLog definition

CREATE TABLE `AttendanceUploadLog` (
  `attendanceUploadLogId` int(11) NOT NULL AUTO_INCREMENT,
  `isProcessed` tinyint(1) NOT NULL DEFAULT 0,
  `attendanceStartDate` date NOT NULL,
  `attendanceEndDate` date NOT NULL,
  `error` text DEFAULT NULL,
  `createdAt` datetime NOT NULL,
  `createdBy` varchar(20) NOT NULL,
  PRIMARY KEY (`attendanceUploadLogId`)
) ENGINE=InnoDB AUTO_INCREMENT=20 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.BankDetails definition

CREATE TABLE `BankDetails` (
  `bankDetailsId` int(11) NOT NULL AUTO_INCREMENT,
  `riderId` varchar(20) DEFAULT NULL,
  `bankName` varchar(200) NOT NULL,
  `accountNumber` varchar(100) DEFAULT NULL,
  `IBAN` varchar(150) DEFAULT NULL,
  `createdAt` datetime NOT NULL,
  `createdBy` varchar(20) NOT NULL,
  `updatedAt` datetime DEFAULT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`bankDetailsId`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.Batch definition

CREATE TABLE `Batch` (
  `batchId` int(11) NOT NULL AUTO_INCREMENT,
  `batchNo` varchar(55) NOT NULL,
  `createdAt` datetime NOT NULL,
  `updatedAt` datetime DEFAULT NULL,
  `createdBy` varchar(20) NOT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`batchId`),
  UNIQUE KEY `batchNo` (`batchNo`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.BatchVehicleCategory definition

CREATE TABLE `BatchVehicleCategory` (
  `batchVehicleCategoryId` int(11) NOT NULL AUTO_INCREMENT,
  `description` varchar(55) NOT NULL,
  PRIMARY KEY (`batchVehicleCategoryId`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.CarEmi definition

CREATE TABLE `CarEmi` (
  `carEmiId` int(11) NOT NULL AUTO_INCREMENT,
  `riderId` varchar(20) NOT NULL,
  `vehicleId` varchar(20) NOT NULL,
  `totalAmount` decimal(12,2) NOT NULL,
  `downPayment` decimal(12,2) NOT NULL,
  `principalAmount` decimal(12,2) NOT NULL,
  `interestRate` decimal(5,2) NOT NULL,
  `tenureMonths` int(11) NOT NULL,
  `monthlyEmi` decimal(12,2) NOT NULL,
  `totalInterest` decimal(12,2) NOT NULL,
  `totalPayable` decimal(12,2) NOT NULL,
  `totalPaid` decimal(12,2) NOT NULL DEFAULT 0.00,
  `contractStartDate` date NOT NULL,
  `isActive` tinyint(1) NOT NULL DEFAULT 1,
  `remarks` text DEFAULT NULL,
  `createdAt` datetime NOT NULL,
  `createdBy` varchar(20) NOT NULL,
  `updatedAt` datetime DEFAULT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  `isEmiSkipped` tinyint(4) DEFAULT 0,
  `skipCount` int(11) DEFAULT NULL,
  PRIMARY KEY (`carEmiId`),
  UNIQUE KEY `uq_rider_vehicle` (`riderId`,`vehicleId`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.Client definition

CREATE TABLE `Client` (
  `clientId` varchar(20) NOT NULL,
  `clientCode` varchar(100) NOT NULL,
  `clientName` varchar(255) NOT NULL,
  `clientEmail` varchar(200) DEFAULT NULL,
  `clientContactPhone` varchar(50) DEFAULT NULL,
  `isActive` tinyint(1) NOT NULL DEFAULT 1,
  `createdAt` datetime NOT NULL,
  `createdBy` varchar(20) NOT NULL,
  `updatedAt` datetime DEFAULT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`clientId`),
  UNIQUE KEY `clientCode` (`clientCode`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.Company definition

CREATE TABLE `Company` (
  `companyId` varchar(20) NOT NULL,
  `idx` varchar(20) DEFAULT NULL,
  `code` varchar(120) DEFAULT NULL,
  `name` varchar(255) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `ownerFirstName` varchar(100) DEFAULT NULL,
  `ownerLastName` varchar(100) DEFAULT NULL,
  `ownerPercentage` int(11) NOT NULL,
  `isActive` tinyint(1) DEFAULT NULL,
  `createdBy` varchar(20) NOT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  `createdAt` datetime NOT NULL,
  `updatedAt` datetime DEFAULT NULL,
  `image` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`companyId`),
  UNIQUE KEY `uq_company_idx` (`idx`),
  UNIQUE KEY `uq_company_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.Document definition

CREATE TABLE `Document` (
  `documentId` int(11) NOT NULL AUTO_INCREMENT,
  `sourceId` varchar(20) NOT NULL,
  `documentTypeId` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `size` double DEFAULT NULL,
  `path` varchar(255) NOT NULL,
  `source` varchar(50) DEFAULT NULL,
  `createdAt` datetime NOT NULL,
  `createdBy` varchar(20) NOT NULL,
  `updatedAt` datetime NOT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  `Image` longblob DEFAULT NULL,
  PRIMARY KEY (`documentId`),
  KEY `companyId` (`sourceId`)
) ENGINE=InnoDB AUTO_INCREMENT=132 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.DocumentType definition

CREATE TABLE `DocumentType` (
  `documentTypeId` int(11) NOT NULL AUTO_INCREMENT,
  `code` varchar(120) DEFAULT NULL,
  `documentHeaderCode` varchar(120) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `createdAt` datetime DEFAULT utc_timestamp(),
  `isMandatory` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`documentTypeId`),
  UNIQUE KEY `code` (`code`)
) ENGINE=InnoDB AUTO_INCREMENT=44 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.IdSequences definition

CREATE TABLE `IdSequences` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `entityType` varchar(50) NOT NULL,
  `yearPrefix` varchar(4) NOT NULL,
  `lastNumber` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_entity_year` (`entityType`,`yearPrefix`)
) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.Payroll definition

CREATE TABLE `Payroll` (
  `payrollId` int(11) NOT NULL AUTO_INCREMENT,
  `payMonth` date NOT NULL,
  `riderId` varchar(20) NOT NULL,
  `riderName` varchar(502) NOT NULL,
  `isFullTime` tinyint(4) NOT NULL,
  `clientId` varchar(20) NOT NULL,
  `clientUserId` varchar(20) NOT NULL,
  `vehicleId` varchar(20) NOT NULL,
  `vehicleNumber` varchar(20) NOT NULL,
  `companyId` varchar(20) NOT NULL,
  `companyCode` varchar(20) NOT NULL,
  `companyName` varchar(502) NOT NULL,
  `grossEarnings` decimal(10,2) DEFAULT 0.00,
  `totalExpenses` decimal(10,2) DEFAULT 0.00,
  `netPay` decimal(10,2) GENERATED ALWAYS AS (`grossEarnings` - `totalExpenses`) STORED,
  `createdAt` datetime NOT NULL,
  `createdBy` varchar(20) DEFAULT NULL,
  `clientName` varchar(502) NOT NULL,
  `iznamalSalary` double(10,2) DEFAULT NULL,
  PRIMARY KEY (`payrollId`),
  UNIQUE KEY `uq_payroll_month_rider` (`payMonth`,`riderId`)
) ENGINE=InnoDB AUTO_INCREMENT=85 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.PayrollErrorLog definition

CREATE TABLE `PayrollErrorLog` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `procedureName` varchar(100) NOT NULL,
  `riderId` varchar(20) DEFAULT NULL,
  `companyId` varchar(20) DEFAULT NULL,
  `payMonth` date DEFAULT NULL,
  `errorMessage` text NOT NULL,
  `errorCode` int(11) DEFAULT NULL,
  `createdAt` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.Permission definition

CREATE TABLE `Permission` (
  `permissionId` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `code` varchar(50) NOT NULL,
  `createdAt` datetime DEFAULT NULL,
  PRIMARY KEY (`permissionId`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.Property definition

CREATE TABLE `Property` (
  `propertyId` int(11) NOT NULL AUTO_INCREMENT,
  `propertyCode` varchar(100) DEFAULT NULL,
  `propertyName` varchar(255) NOT NULL,
  `availableQuantity` int(11) NOT NULL DEFAULT 0,
  `description` varchar(500) DEFAULT NULL,
  `isActive` tinyint(1) NOT NULL DEFAULT 1,
  `createdAt` datetime NOT NULL,
  `createdBy` varchar(20) NOT NULL,
  `updatedAt` datetime NOT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  `totalQuantity` int(11) NOT NULL,
  PRIMARY KEY (`propertyId`),
  UNIQUE KEY `propertyName` (`propertyName`),
  UNIQUE KEY `propertyCode` (`propertyCode`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.RiderOrderUploadLog definition

CREATE TABLE `RiderOrderUploadLog` (
  `riderOrderUploadLogId` int(11) NOT NULL AUTO_INCREMENT,
  `companyId` varchar(20) NOT NULL,
  `clientId` varchar(20) DEFAULT NULL,
  `orderMonth` date NOT NULL,
  `isProcessed` tinyint(1) NOT NULL DEFAULT 0,
  `error` text DEFAULT NULL,
  `createdAt` datetime NOT NULL,
  `createdBy` varchar(20) DEFAULT NULL,
  `fileName` varchar(200) NOT NULL DEFAULT '',
  PRIMARY KEY (`riderOrderUploadLogId`)
) ENGINE=InnoDB AUTO_INCREMENT=45 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.RiderStatus definition

CREATE TABLE `RiderStatus` (
  `statusId` int(11) NOT NULL AUTO_INCREMENT,
  `statusName` varchar(50) NOT NULL,
  `statusOrder` int(11) NOT NULL,
  `isActive` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`statusId`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.`Role` definition

CREATE TABLE `Role` (
  `roleId` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(150) NOT NULL,
  `description` varchar(255) NOT NULL,
  `isActive` tinyint(1) DEFAULT NULL,
  `createdAt` datetime NOT NULL,
  `updatedAt` datetime DEFAULT NULL,
  PRIMARY KEY (`roleId`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.Task definition

CREATE TABLE `Task` (
  `taskId` int(11) NOT NULL,
  `taskCode` varchar(50) DEFAULT NULL,
  `taskName` varchar(200) NOT NULL,
  `description` text DEFAULT NULL,
  `processType` varchar(50) NOT NULL,
  `performedBy` int(11) NOT NULL,
  `defaultDays` int(11) DEFAULT NULL,
  `taskOrder` int(11) NOT NULL,
  `jsonTemplate` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`jsonTemplate`)),
  `isActive` tinyint(1) NOT NULL,
  `createdAt` datetime NOT NULL,
  `updatedAt` datetime DEFAULT NULL,
  PRIMARY KEY (`taskId`),
  UNIQUE KEY `uq_taskCode_processType` (`taskCode`,`processType`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.TaskStatus definition

CREATE TABLE `TaskStatus` (
  `taskStatusId` int(11) NOT NULL,
  `taskStatusCode` varchar(50) NOT NULL,
  `taskStatusName` varchar(100) NOT NULL,
  `description` varchar(200) DEFAULT NULL,
  `createdAt` datetime DEFAULT utc_timestamp(),
  PRIMARY KEY (`taskStatusId`),
  UNIQUE KEY `taskStatusCode` (`taskStatusCode`),
  UNIQUE KEY `taskStatusName` (`taskStatusName`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.TicketType definition

CREATE TABLE `TicketType` (
  `typeId` int(11) NOT NULL AUTO_INCREMENT,
  `type` enum('PASSPORT','SUPPORT') DEFAULT NULL,
  `code` varchar(40) NOT NULL,
  `description` varchar(40) NOT NULL,
  PRIMARY KEY (`typeId`)
) ENGINE=InnoDB AUTO_INCREMENT=28 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.temp definition

CREATE TABLE `temp` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `logTime` datetime DEFAULT current_timestamp(),
  `logNo` int(11) DEFAULT NULL,
  `message` text DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.CompanyDocument definition

CREATE TABLE `CompanyDocument` (
  `documentId` int(11) NOT NULL AUTO_INCREMENT,
  `companyId` varchar(20) DEFAULT NULL,
  `documentTypeId` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `size` double DEFAULT NULL,
  `path` varchar(255) NOT NULL,
  `source` varchar(50) DEFAULT NULL,
  `createdAt` datetime NOT NULL,
  `createdBy` varchar(20) NOT NULL,
  `updatedAt` datetime NOT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  `expiryDt` datetime DEFAULT NULL,
  `Image` longblob DEFAULT NULL,
  PRIMARY KEY (`documentId`),
  KEY `fk_companydocument_company` (`companyId`),
  CONSTRAINT `fk_companydocument_company` FOREIGN KEY (`companyId`) REFERENCES `Company` (`companyId`)
) ENGINE=InnoDB AUTO_INCREMENT=47 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.CompanyPayrollSummary definition

CREATE TABLE `CompanyPayrollSummary` (
  `companyPayrollSummaryId` int(11) NOT NULL AUTO_INCREMENT,
  `companyId` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `payMonth` date NOT NULL,
  `totalPayableAmount` decimal(12,2) DEFAULT 0.00,
  `createdBy` varchar(20) DEFAULT NULL,
  `createdAt` datetime NOT NULL,
  `ridersProcessed` int(11) DEFAULT 0,
  `ridersSkipped` int(11) DEFAULT 0,
  `status` enum('PROCESSING','COMPLETED','PARTIALLY_DONE') NOT NULL DEFAULT 'PROCESSING',
  `updatedAt` date DEFAULT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`companyPayrollSummaryId`),
  UNIQUE KEY `uq_company_month` (`companyId`,`payMonth`),
  CONSTRAINT `fk_cps_company` FOREIGN KEY (`companyId`) REFERENCES `Company` (`companyId`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.CompanyPerformance definition

CREATE TABLE `CompanyPerformance` (
  `companyPerformanceId` int(11) NOT NULL AUTO_INCREMENT,
  `companyId` varchar(20) NOT NULL,
  `accountManager` varchar(100) DEFAULT NULL,
  `performanceMonth` date NOT NULL,
  `completedPickups` int(11) NOT NULL DEFAULT 0,
  `pickupPay` decimal(10,2) NOT NULL DEFAULT 0.00,
  `completedDropoffs` int(11) NOT NULL DEFAULT 0,
  `dropoffPay` decimal(10,2) NOT NULL DEFAULT 0.00,
  `serviceLevelAchievementPay` decimal(10,2) NOT NULL DEFAULT 0.00,
  `operatorAppDeduction` decimal(10,2) NOT NULL DEFAULT 0.00,
  `totalPayment` decimal(10,2) NOT NULL DEFAULT 0.00,
  `contractFee` decimal(10,2) NOT NULL DEFAULT 0.00,
  `eidQuestPay` decimal(10,2) NOT NULL DEFAULT 0.00,
  `finalPayment` decimal(10,2) NOT NULL DEFAULT 0.00,
  `expenses` decimal(10,2) DEFAULT NULL,
  `createdAt` datetime NOT NULL,
  `createdBy` varchar(20) DEFAULT NULL,
  `updatedAt` datetime DEFAULT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`companyPerformanceId`),
  UNIQUE KEY `uq_company_month` (`companyId`,`performanceMonth`),
  CONSTRAINT `fk_companyPerformance_company` FOREIGN KEY (`companyId`) REFERENCES `Company` (`companyId`) ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.DocumentTypeExpiry definition

CREATE TABLE `DocumentTypeExpiry` (
  `documentTypeExpiryId` int(11) NOT NULL AUTO_INCREMENT,
  `sourceId` varchar(20) NOT NULL,
  `source` varchar(50) NOT NULL,
  `documentTypeId` int(11) NOT NULL,
  `expiryDate` date NOT NULL,
  `createdAt` datetime NOT NULL,
  `updatedAt` datetime DEFAULT NULL,
  `createdBy` varchar(20) NOT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`documentTypeExpiryId`),
  UNIQUE KEY `sourceId` (`sourceId`,`source`,`documentTypeId`),
  KEY `FK_DocumentTypeExpiry_DocumentType` (`documentTypeId`),
  CONSTRAINT `FK_DocumentTypeExpiry_DocumentType` FOREIGN KEY (`documentTypeId`) REFERENCES `DocumentType` (`documentTypeId`)
) ENGINE=InnoDB AUTO_INCREMENT=71 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.Helpdesk definition

CREATE TABLE `Helpdesk` (
  `ticketId` int(11) NOT NULL AUTO_INCREMENT,
  `type` int(11) NOT NULL,
  `status` enum('OPEN','CLOSED') NOT NULL,
  `riderId` varchar(40) NOT NULL,
  `createdDate` datetime NOT NULL,
  `closedDate` datetime DEFAULT NULL,
  `comments` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`comments`)),
  `createdBy` varchar(40) NOT NULL,
  `createdAt` datetime NOT NULL,
  `updatedBy` varchar(40) DEFAULT NULL,
  `updatedAt` datetime NOT NULL,
  PRIMARY KEY (`ticketId`),
  KEY `fk_helpdesk_type` (`type`),
  CONSTRAINT `fk_helpdesk_type` FOREIGN KEY (`type`) REFERENCES `TicketType` (`typeId`) ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.OrderValue definition

CREATE TABLE `OrderValue` (
  `orderValueId` int(11) NOT NULL AUTO_INCREMENT,
  `SingleOrderValue` decimal(38,20) DEFAULT NULL,
  `DoubleOrderValue` decimal(38,20) DEFAULT NULL,
  `clientId` varchar(20) DEFAULT NULL,
  `batchId` int(11) DEFAULT NULL,
  `batchVehicleCategoryId` int(11) DEFAULT NULL,
  `createdAt` datetime NOT NULL,
  `updatedAt` datetime DEFAULT NULL,
  `createdBy` varchar(20) NOT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`orderValueId`),
  KEY `batchId` (`batchId`),
  KEY `fk_ordervalue_client` (`clientId`),
  CONSTRAINT `OrderValue_ibfk_2` FOREIGN KEY (`batchId`) REFERENCES `Batch` (`batchId`) ON DELETE CASCADE,
  CONSTRAINT `fk_ordervalue_client` FOREIGN KEY (`clientId`) REFERENCES `Client` (`clientId`)
) ENGINE=InnoDB AUTO_INCREMENT=41 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.PageModule definition

CREATE TABLE `PageModule` (
  `pageModuleId` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(150) NOT NULL,
  `code` varchar(255) NOT NULL,
  `parentModuleId` int(11) DEFAULT NULL,
  `createdAt` datetime NOT NULL,
  `updatedAt` datetime DEFAULT NULL,
  PRIMARY KEY (`pageModuleId`),
  KEY `fk_parent_module` (`parentModuleId`),
  CONSTRAINT `fk_parent_module` FOREIGN KEY (`parentModuleId`) REFERENCES `PageModule` (`pageModuleId`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.Partner definition

CREATE TABLE `Partner` (
  `partnerId` int(11) NOT NULL AUTO_INCREMENT,
  `companyId` varchar(20) DEFAULT NULL,
  `firstName` varchar(255) NOT NULL,
  `lastName` varchar(255) DEFAULT NULL,
  `createdBy` varchar(20) NOT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  `percentage` int(11) NOT NULL DEFAULT 0,
  `createdAt` datetime NOT NULL,
  `updatedAt` datetime DEFAULT NULL,
  PRIMARY KEY (`partnerId`),
  KEY `fk_partner_company` (`companyId`),
  CONSTRAINT `fk_partner_company` FOREIGN KEY (`companyId`) REFERENCES `Company` (`companyId`)
) ENGINE=InnoDB AUTO_INCREMENT=111 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.PassportRequest definition

CREATE TABLE `PassportRequest` (
  `ticketId` int(11) NOT NULL AUTO_INCREMENT,
  `type` int(11) NOT NULL,
  `status` enum('Passport Requested','Approved','Rejected','Passport Collected By Rider','Passport Received','Closed') NOT NULL,
  `riderId` varchar(40) NOT NULL,
  `createdDate` datetime NOT NULL,
  `closedDate` datetime DEFAULT NULL,
  `comments` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`comments`)),
  `createdBy` varchar(40) NOT NULL,
  `createdAt` datetime NOT NULL,
  `updatedBy` varchar(40) DEFAULT NULL,
  `updatedAt` datetime NOT NULL,
  PRIMARY KEY (`ticketId`),
  KEY `fk_passport_request_type` (`type`),
  CONSTRAINT `fk_passport_request_type` FOREIGN KEY (`type`) REFERENCES `TicketType` (`typeId`) ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.PayrollEarnings definition

CREATE TABLE `PayrollEarnings` (
  `payrollEarningId` int(11) NOT NULL AUTO_INCREMENT,
  `payrollId` int(11) NOT NULL,
  `singleOrderCount` int(11) NOT NULL DEFAULT 0,
  `doubleOrderCount` int(11) NOT NULL DEFAULT 0,
  `singleOrderRate` decimal(10,2) DEFAULT 0.00,
  `doubleOrderRate` decimal(10,2) DEFAULT 0.00,
  `batchNo` varchar(20) NOT NULL,
  PRIMARY KEY (`payrollEarningId`),
  KEY `payrollId` (`payrollId`),
  CONSTRAINT `PayrollEarnings_ibfk_1` FOREIGN KEY (`payrollId`) REFERENCES `Payroll` (`payrollId`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.PayrollExpenses definition

CREATE TABLE `PayrollExpenses` (
  `payrollExpenseId` int(11) NOT NULL AUTO_INCREMENT,
  `payrollId` int(11) NOT NULL,
  `trafficFines` decimal(10,2) DEFAULT 0.00,
  `adminFees` decimal(10,2) DEFAULT 0.00,
  `processingFees` decimal(10,2) DEFAULT 0.00,
  `garageBills` decimal(10,2) DEFAULT 0.00,
  `maroorFines` decimal(10,2) DEFAULT 0.00,
  `previousBalances` decimal(10,2) DEFAULT 0.00,
  `dgDeduction` decimal(10,2) DEFAULT 0.00,
  `salesCash` decimal(10,2) DEFAULT 0.00,
  `incentives` decimal(10,2) DEFAULT 0.00,
  `extras` decimal(10,2) DEFAULT 0.00,
  `mobileBills` decimal(10,2) DEFAULT 0.00,
  PRIMARY KEY (`payrollExpenseId`),
  KEY `payrollId` (`payrollId`),
  CONSTRAINT `PayrollExpenses_ibfk_1` FOREIGN KEY (`payrollId`) REFERENCES `Payroll` (`payrollId`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.PayrollVehicleEMI definition

CREATE TABLE `PayrollVehicleEMI` (
  `payrollVehicleEmiId` int(11) NOT NULL AUTO_INCREMENT,
  `payrollId` int(11) NOT NULL,
  `vehicleId` varchar(20) DEFAULT NULL,
  `isEmiSkipped` tinyint(4) NOT NULL DEFAULT 0,
  `emiMonth` date NOT NULL,
  `principalAmount` decimal(10,2) DEFAULT NULL,
  `monthlyEmi` decimal(10,2) NOT NULL,
  `remainingBalance` decimal(10,2) DEFAULT NULL,
  `interestRate` decimal(5,2) DEFAULT NULL,
  PRIMARY KEY (`payrollVehicleEmiId`),
  KEY `payrollId` (`payrollId`),
  CONSTRAINT `PayrollVehicleEMI_ibfk_1` FOREIGN KEY (`payrollId`) REFERENCES `Payroll` (`payrollId`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.Rider definition

CREATE TABLE `Rider` (
  `riderId` varchar(20) NOT NULL,
  `riderName` varchar(255) NOT NULL,
  `dob` datetime DEFAULT NULL,
  `nationality` varchar(50) DEFAULT NULL,
  `civilId` varchar(100) DEFAULT NULL,
  `passportNumber` varchar(100) DEFAULT NULL,
  `passportExpiryDate` datetime DEFAULT NULL,
  `licenseNumber` varchar(100) DEFAULT NULL,
  `licenseExpiryDate` datetime DEFAULT NULL,
  `mobileNumber` varchar(50) DEFAULT NULL,
  `alternateMobileNumber` varchar(50) DEFAULT NULL,
  `personalEmail` varchar(200) DEFAULT NULL,
  `suretyPersonName` varchar(100) DEFAULT NULL,
  `suretyPersonEmail` varchar(200) DEFAULT NULL,
  `suretyPersonPhone` varchar(50) DEFAULT NULL,
  `iznamalSalary` double DEFAULT NULL,
  `hireTypeId` int(11) DEFAULT NULL,
  `statusId` int(11) DEFAULT NULL,
  `profession` varchar(200) DEFAULT NULL,
  `workPermitIssued` tinyint(1) NOT NULL DEFAULT 0,
  `workPermitIssuedDate` datetime DEFAULT NULL,
  `workPermitExpiryDate` datetime DEFAULT NULL,
  `foodHandlers` tinyint(1) NOT NULL DEFAULT 1,
  `foodHandlersExpiryDate` datetime DEFAULT NULL,
  `companyId` varchar(20) DEFAULT NULL,
  `isActive` tinyint(1) NOT NULL DEFAULT 1,
  `remarks` text DEFAULT NULL,
  `createdAt` datetime NOT NULL,
  `createdBy` varchar(20) NOT NULL,
  `updatedAt` datetime DEFAULT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  `trafficFines` int(10) NOT NULL DEFAULT 0,
  `advances` int(10) NOT NULL DEFAULT 0,
  `adminFees` int(10) NOT NULL DEFAULT 0,
  `akamaRenewalAmount` int(10) NOT NULL DEFAULT 0,
  `processingFees` int(10) NOT NULL DEFAULT 0,
  `mobileBills` int(10) NOT NULL DEFAULT 0,
  `garageBills` int(10) NOT NULL DEFAULT 0,
  `maroorFines` int(10) NOT NULL DEFAULT 0,
  `incentives` int(10) NOT NULL DEFAULT 0,
  `previousBalances` int(10) NOT NULL DEFAULT 0,
  `dgDeduction` int(10) NOT NULL DEFAULT 0,
  `miscellaneousExpenses` int(10) NOT NULL DEFAULT 0,
  `employmentType` varchar(22) NOT NULL,
  PRIMARY KEY (`riderId`),
  KEY `fk_rider_hiretype` (`hireTypeId`),
  KEY `fk_rider_status` (`statusId`),
  KEY `fk_rider_company` (`companyId`),
  CONSTRAINT `fk_rider_company` FOREIGN KEY (`companyId`) REFERENCES `Company` (`companyId`),
  CONSTRAINT `fk_rider_status` FOREIGN KEY (`statusId`) REFERENCES `RiderStatus` (`statusId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.RiderOrder definition

CREATE TABLE `RiderOrder` (
  `riderOrderId` int(11) NOT NULL AUTO_INCREMENT,
  `riderId` varchar(20) NOT NULL,
  `companyId` varchar(20) NOT NULL,
  `clientId` varchar(20) NOT NULL,
  `clientUserId` int(11) NOT NULL,
  `vehicleType` enum('CAR','MOTOR_BIKE') DEFAULT NULL,
  `batchVehicleCategoryId` int(11) NOT NULL,
  `orderMonth` date NOT NULL,
  `batchNo` varchar(20) DEFAULT NULL,
  `evaluatedHours` decimal(5,2) NOT NULL,
  `singleOrder` int(11) NOT NULL,
  `doubleOrder` int(11) NOT NULL,
  `totalPayment` decimal(10,2) NOT NULL,
  `createdAt` datetime NOT NULL,
  `createdBy` varchar(20) DEFAULT NULL,
  `updatedAt` datetime DEFAULT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`riderOrderId`),
  UNIQUE KEY `uq_rider_company_month_batch_vehicle` (`riderId`,`companyId`,`orderMonth`,`batchNo`,`vehicleType`),
  KEY `idx_order_month_rider` (`riderId`,`orderMonth`),
  KEY `idx_month_batch` (`orderMonth`,`batchNo`),
  KEY `batchVehicleCategoryId` (`batchVehicleCategoryId`),
  CONSTRAINT `RiderOrder_ibfk_1` FOREIGN KEY (`riderId`) REFERENCES `Rider` (`riderId`),
  CONSTRAINT `RiderOrder_ibfk_2` FOREIGN KEY (`batchVehicleCategoryId`) REFERENCES `BatchVehicleCategory` (`batchVehicleCategoryId`)
) ENGINE=InnoDB AUTO_INCREMENT=301 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.RiderPerformance definition

CREATE TABLE `RiderPerformance` (
  `riderPerformanceId` int(11) NOT NULL AUTO_INCREMENT,
  `clientId` varchar(20) NOT NULL,
  `clientUserId` int(11) NOT NULL,
  `riderId` varchar(20) NOT NULL,
  `accountManager` varchar(100) DEFAULT NULL,
  `currentZone` varchar(100) DEFAULT NULL,
  `performanceMonth` date NOT NULL,
  `lastBatchNo` int(11) DEFAULT NULL,
  `tenureWeeks` int(11) NOT NULL DEFAULT 0,
  `workingDays` int(11) NOT NULL DEFAULT 0,
  `evaluatedShifts` int(11) NOT NULL DEFAULT 0,
  `plannedWorkingHours` decimal(5,2) NOT NULL DEFAULT 0.00,
  `actualWorkingHours` decimal(5,2) NOT NULL DEFAULT 0.00,
  `avpPercentage` decimal(5,2) NOT NULL DEFAULT 0.00,
  `avgWorkingHoursPerDay` decimal(5,2) NOT NULL DEFAULT 0.00,
  `avgShiftDuration` decimal(5,2) NOT NULL DEFAULT 0.00,
  `breakHours` decimal(5,2) NOT NULL DEFAULT 0.00,
  `breakDurationPercentage` decimal(5,2) NOT NULL DEFAULT 0.00,
  `avgDeliveriesPerHour` decimal(5,2) NOT NULL DEFAULT 0.00,
  `notificationCount` int(11) NOT NULL DEFAULT 0,
  `acceptanceCount` int(11) NOT NULL DEFAULT 0,
  `missedOrders` int(11) NOT NULL DEFAULT 0,
  `manualUndispatched` int(11) NOT NULL DEFAULT 0,
  `acceptanceRate` decimal(5,2) NOT NULL DEFAULT 0.00,
  `createdAt` datetime NOT NULL,
  `createdBy` varchar(20) DEFAULT NULL,
  `updatedAt` datetime DEFAULT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`riderPerformanceId`),
  UNIQUE KEY `uq_riderPerformance` (`clientId`,`riderId`,`performanceMonth`),
  KEY `fk_riderPerformance_rider` (`riderId`),
  CONSTRAINT `fk_riderPerformance_rider` FOREIGN KEY (`riderId`) REFERENCES `Rider` (`riderId`) ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.RiderProperty definition

CREATE TABLE `RiderProperty` (
  `riderPropertyId` int(11) NOT NULL AUTO_INCREMENT,
  `riderId` varchar(20) DEFAULT NULL,
  `propertyId` int(11) NOT NULL,
  `quantity` int(11) NOT NULL DEFAULT 1,
  `isActive` tinyint(1) NOT NULL DEFAULT 1,
  `remarks` varchar(500) DEFAULT NULL,
  `createdAt` datetime NOT NULL,
  `createdBy` varchar(20) NOT NULL,
  `updatedAt` datetime DEFAULT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`riderPropertyId`),
  UNIQUE KEY `uq_riderprop_property_active` (`riderId`,`propertyId`),
  KEY `fk_riderprop_property` (`propertyId`),
  CONSTRAINT `fk_riderprop_property` FOREIGN KEY (`propertyId`) REFERENCES `Property` (`propertyId`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_riderprop_rider` FOREIGN KEY (`riderId`) REFERENCES `Rider` (`riderId`)
) ENGINE=InnoDB AUTO_INCREMENT=26 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.RolePermission definition

CREATE TABLE `RolePermission` (
  `rolePermissionId` int(11) NOT NULL AUTO_INCREMENT,
  `roleId` int(11) NOT NULL,
  `pageModuleId` int(11) NOT NULL,
  `permission` int(11) NOT NULL DEFAULT 0,
  `createdBy` varchar(20) NOT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  `createdAt` datetime NOT NULL,
  `updatedAt` datetime DEFAULT NULL,
  PRIMARY KEY (`rolePermissionId`),
  KEY `roleId` (`roleId`),
  KEY `pageModuleId` (`pageModuleId`),
  CONSTRAINT `RolePermission_ibfk_1` FOREIGN KEY (`roleId`) REFERENCES `Role` (`roleId`)
) ENGINE=InnoDB AUTO_INCREMENT=103 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.SalesCashDetails definition

CREATE TABLE `SalesCashDetails` (
  `salesCashDetailsId` int(11) NOT NULL AUTO_INCREMENT,
  `clientUserId` int(11) NOT NULL,
  `clientId` varchar(20) NOT NULL,
  `riderId` varchar(20) NOT NULL,
  `companyId` varchar(20) NOT NULL,
  `companyCode` varchar(50) NOT NULL,
  `status` varchar(50) NOT NULL,
  `entryDate` date NOT NULL,
  `salesAmount` decimal(18,2) NOT NULL DEFAULT 0.00,
  `collectedAmount` decimal(18,2) DEFAULT 0.00,
  `cash` decimal(18,2) DEFAULT 0.00,
  `bankTransfer` decimal(18,2) DEFAULT 0.00,
  `incentives` decimal(18,2) DEFAULT 0.00,
  `adjustments` decimal(18,2) DEFAULT 0.00,
  `openingBalance` decimal(18,2) DEFAULT 0.00,
  `totalSales` decimal(18,2) DEFAULT 0.00,
  `totalCollection` decimal(18,2) DEFAULT 0.00,
  `pendingDues` decimal(18,2) NOT NULL DEFAULT 0.00,
  `createdAt` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`salesCashDetailsId`),
  UNIQUE KEY `uq_entry_rider_date` (`riderId`,`entryDate`),
  KEY `fk_salescashdetails_company` (`companyId`),
  KEY `fk_salescashdetails_client` (`clientId`),
  CONSTRAINT `fk_salescashdetails_client` FOREIGN KEY (`clientId`) REFERENCES `Client` (`clientId`) ON UPDATE CASCADE,
  CONSTRAINT `fk_salescashdetails_company` FOREIGN KEY (`companyId`) REFERENCES `Company` (`companyId`) ON UPDATE CASCADE,
  CONSTRAINT `fk_salescashdetails_rider` FOREIGN KEY (`riderId`) REFERENCES `Rider` (`riderId`) ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=44 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.SalesCashEntry definition

CREATE TABLE `SalesCashEntry` (
  `salesCashEntryId` int(11) NOT NULL AUTO_INCREMENT,
  `clientId` varchar(20) NOT NULL,
  `companyId` varchar(20) NOT NULL,
  `clientUserId` int(11) NOT NULL,
  `riderId` varchar(20) NOT NULL,
  `entryDate` date NOT NULL,
  `collectionAmount` decimal(18,2) NOT NULL DEFAULT 0.00,
  `isDraft` tinyint(1) NOT NULL DEFAULT 1,
  `remarks` varchar(500) DEFAULT NULL,
  `createdBy` varchar(20) NOT NULL,
  `createdAt` datetime NOT NULL,
  `exportedAt` datetime DEFAULT NULL,
  PRIMARY KEY (`salesCashEntryId`),
  UNIQUE KEY `uq_company_date` (`clientUserId`,`entryDate`),
  KEY `fk_salescashentry_company` (`companyId`),
  KEY `fk_salescashentry_rider` (`riderId`),
  KEY `fk_salescashentry_client` (`clientId`),
  CONSTRAINT `fk_salescashentry_client` FOREIGN KEY (`clientId`) REFERENCES `Client` (`clientId`) ON UPDATE CASCADE,
  CONSTRAINT `fk_salescashentry_company` FOREIGN KEY (`companyId`) REFERENCES `Company` (`companyId`) ON UPDATE CASCADE,
  CONSTRAINT `fk_salescashentry_rider` FOREIGN KEY (`riderId`) REFERENCES `Rider` (`riderId`) ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.SimCard definition

CREATE TABLE `SimCard` (
  `simId` int(11) NOT NULL AUTO_INCREMENT,
  `mobileNumber` varchar(20) NOT NULL,
  `assignedTo` varchar(20) DEFAULT NULL,
  `createdAt` datetime NOT NULL,
  `createdBy` varchar(20) DEFAULT NULL,
  `updatedAt` datetime DEFAULT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  `notes` text DEFAULT NULL,
  PRIMARY KEY (`simId`),
  UNIQUE KEY `mobileNumber` (`mobileNumber`),
  KEY `fk_simcards_rider` (`assignedTo`),
  CONSTRAINT `fk_simcards_rider` FOREIGN KEY (`assignedTo`) REFERENCES `Rider` (`riderId`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.`User` definition

CREATE TABLE `User` (
  `userId` varchar(20) NOT NULL,
  `firstName` varchar(100) NOT NULL,
  `lastName` varchar(100) DEFAULT NULL,
  `email` varchar(150) NOT NULL,
  `passwordHash` varchar(255) NOT NULL,
  `phone` varchar(20) NOT NULL,
  `roleId` int(11) NOT NULL,
  `isActive` tinyint(1) DEFAULT NULL,
  `lastLoginDt` datetime DEFAULT current_timestamp(),
  `isLoggedIn` tinyint(1) NOT NULL DEFAULT 0,
  `isRememberMe` tinyint(1) NOT NULL DEFAULT 0,
  `createdBy` varchar(20) NOT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  `createdAt` datetime NOT NULL,
  `updatedAt` datetime DEFAULT NULL,
  `Image` varchar(255) DEFAULT NULL,
  `riderId` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`userId`),
  UNIQUE KEY `email` (`email`),
  KEY `roleId` (`roleId`),
  KEY `fk_user_rider` (`riderId`),
  CONSTRAINT `User_ibfk_1` FOREIGN KEY (`roleId`) REFERENCES `Role` (`roleId`),
  CONSTRAINT `fk_user_rider` FOREIGN KEY (`riderId`) REFERENCES `Rider` (`riderId`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.UserCompany definition

CREATE TABLE `UserCompany` (
  `userId` varchar(20) NOT NULL,
  `companyId` varchar(20) NOT NULL,
  `createdBy` varchar(20) NOT NULL,
  `createdAt` datetime NOT NULL,
  PRIMARY KEY (`userId`,`companyId`),
  KEY `companyId` (`companyId`),
  CONSTRAINT `UserCompany_ibfk_1` FOREIGN KEY (`userId`) REFERENCES `User` (`userId`) ON DELETE CASCADE,
  CONSTRAINT `UserCompany_ibfk_2` FOREIGN KEY (`companyId`) REFERENCES `Company` (`companyId`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.Vehicle definition

CREATE TABLE `Vehicle` (
  `vehicleId` varchar(20) NOT NULL,
  `vehicleType` enum('Bike','Car','Others') DEFAULT NULL,
  `vehicleNumber` varchar(50) NOT NULL,
  `vehicleBrand` varchar(50) NOT NULL,
  `vehicleModel` varchar(50) NOT NULL,
  `yearManufactured` datetime DEFAULT NULL,
  `isAssigned` tinyint(1) NOT NULL,
  `remarks` varchar(200) DEFAULT NULL,
  `ownerType` enum('Company','EmployeeOwned','Rental','Installment') DEFAULT NULL,
  `registeredOn` enum('Company','EmployeeOwned') DEFAULT NULL,
  `isAdvertisingSticker` tinyint(1) DEFAULT NULL,
  `isStickeringPermission` tinyint(1) DEFAULT NULL,
  `stickeringPermissionExpiry` datetime DEFAULT NULL,
  `isFoodPaper` tinyint(1) DEFAULT NULL,
  `foodPaperExpiry` datetime DEFAULT NULL,
  `spareKeys` enum('Office','Driver','N/A') DEFAULT NULL,
  `createdAt` datetime NOT NULL,
  `updatedAt` datetime DEFAULT NULL,
  `createdBy` varchar(20) NOT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  `companyId` varchar(20) DEFAULT NULL,
  `isActive` tinyint(4) DEFAULT 1,
  PRIMARY KEY (`vehicleId`),
  KEY `fk_vehicle_company` (`companyId`),
  CONSTRAINT `fk_vehicle_company` FOREIGN KEY (`companyId`) REFERENCES `Company` (`companyId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.VehicleImage definition

CREATE TABLE `VehicleImage` (
  `vehicleImageId` int(11) NOT NULL AUTO_INCREMENT,
  `path` varchar(255) NOT NULL,
  `createdAt` datetime NOT NULL,
  `createdBy` varchar(20) DEFAULT NULL,
  `vehicleId` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`vehicleImageId`),
  KEY `fk_vehicleimage_vehicle` (`vehicleId`),
  CONSTRAINT `fk_vehicleimage_vehicle` FOREIGN KEY (`vehicleId`) REFERENCES `Vehicle` (`vehicleId`)
) ENGINE=InnoDB AUTO_INCREMENT=70 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.Attendance definition

CREATE TABLE `Attendance` (
  `attendanceId` int(11) NOT NULL AUTO_INCREMENT,
  `riderId` varchar(20) DEFAULT NULL,
  `clientUserId` int(11) NOT NULL,
  `attendanceDate` date NOT NULL,
  `status` enum('WORKED','NO_SHIFT','NO_SHOW','LATE_LOGIN','SUSPENDED','EMPTY') DEFAULT NULL,
  PRIMARY KEY (`attendanceId`),
  UNIQUE KEY `uq_attendance_rider_date` (`riderId`,`attendanceDate`),
  KEY `idx_rider_date` (`riderId`,`attendanceDate`),
  KEY `idx_date` (`attendanceDate`),
  KEY `idx_status_date` (`status`,`attendanceDate`),
  CONSTRAINT `fk_attendance_rider` FOREIGN KEY (`riderId`) REFERENCES `Rider` (`riderId`)
) ENGINE=InnoDB AUTO_INCREMENT=555 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.ClientRiderConfig definition

CREATE TABLE `ClientRiderConfig` (
  `clientRiderConfigId` int(11) NOT NULL AUTO_INCREMENT,
  `clientUserId` int(11) NOT NULL,
  `riderId` varchar(20) DEFAULT NULL,
  `startDate` datetime NOT NULL,
  `endDate` datetime DEFAULT NULL,
  `isActive` tinyint(1) NOT NULL DEFAULT 1,
  `createdAt` datetime NOT NULL,
  `createdBy` varchar(20) NOT NULL,
  `updatedAt` datetime DEFAULT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`clientRiderConfigId`),
  KEY `fk_clientriderconfig_rider` (`riderId`),
  CONSTRAINT `fk_clientriderconfig_rider` FOREIGN KEY (`riderId`) REFERENCES `Rider` (`riderId`),
  CONSTRAINT `CONSTRAINT_1` CHECK (`endDate` is null or `endDate` >= `startDate`)
) ENGINE=InnoDB AUTO_INCREMENT=59 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.ClientUserId definition

CREATE TABLE `ClientUserId` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `clientUserId` int(11) NOT NULL,
  `riderId` varchar(20) DEFAULT NULL,
  `createdAt` datetime NOT NULL,
  `updatedAt` datetime NOT NULL,
  `createdBy` varchar(20) NOT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  `isActive` tinyint(1) NOT NULL DEFAULT 1,
  `clientId` varchar(20) DEFAULT NULL,
  `isAssigned` tinyint(1) NOT NULL DEFAULT 0,
  `tempRiderId` varchar(20) DEFAULT NULL,
  `contractExpiry` date NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_clientUserId` (`clientUserId`),
  KEY `createdBy` (`createdBy`),
  KEY `updatedBy` (`updatedBy`),
  KEY `fk_clientuserid_client` (`clientId`),
  KEY `fk_clientuserid_temprider` (`tempRiderId`),
  CONSTRAINT `fk_clientuserid_client` FOREIGN KEY (`clientId`) REFERENCES `Client` (`clientId`),
  CONSTRAINT `fk_clientuserid_temprider` FOREIGN KEY (`tempRiderId`) REFERENCES `Rider` (`riderId`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=38 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.HrWorkflow definition

CREATE TABLE `HrWorkflow` (
  `hrWorkflowId` int(11) NOT NULL AUTO_INCREMENT,
  `riderId` varchar(20) DEFAULT NULL,
  `taskId` int(11) NOT NULL,
  `taskStatusId` int(11) NOT NULL,
  `taskDetails` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`taskDetails`)),
  `taskOrder` int(11) NOT NULL,
  `remarks` text DEFAULT NULL,
  `startDate` datetime DEFAULT NULL,
  `endDate` datetime DEFAULT NULL,
  `dueDate` datetime DEFAULT NULL,
  `isActive` tinyint(1) NOT NULL DEFAULT 1,
  `createdAt` datetime NOT NULL,
  `createdBy` varchar(20) NOT NULL,
  `updatedAt` datetime DEFAULT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`hrWorkflowId`),
  KEY `fk_hr_taskStatus` (`taskStatusId`),
  KEY `fk_hr_task` (`taskId`),
  KEY `fk_hrworkflow_rider` (`riderId`),
  CONSTRAINT `fk_hr_task` FOREIGN KEY (`taskId`) REFERENCES `Task` (`taskId`) ON UPDATE CASCADE,
  CONSTRAINT `fk_hr_taskStatus` FOREIGN KEY (`taskStatusId`) REFERENCES `TaskStatus` (`taskStatusId`),
  CONSTRAINT `fk_hrworkflow_rider` FOREIGN KEY (`riderId`) REFERENCES `Rider` (`riderId`)
) ENGINE=InnoDB AUTO_INCREMENT=192 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.LeaveRequest definition

CREATE TABLE `LeaveRequest` (
  `leaveRequestId` int(11) NOT NULL AUTO_INCREMENT,
  `riderId` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `leaveType` enum('AnnualVacation','EmergencyVacation','SickLeave','VehicleIssue','Others') NOT NULL,
  `otherReason` varchar(105) DEFAULT NULL,
  `startDate` date NOT NULL,
  `endDate` date NOT NULL,
  `totalDays` int(11) GENERATED ALWAYS AS (to_days(`endDate`) - to_days(`startDate`) + 1) STORED,
  `status` enum('PendingReview','SupervisorApproved','Approved','OnHold','Rejected','Cancelled') DEFAULT 'PendingReview',
  `createdAt` datetime NOT NULL,
  `createdBy` varchar(20) DEFAULT NULL,
  `updatedAt` datetime DEFAULT NULL,
  `updatedBy` varchar(20) DEFAULT NULL,
  `rejectReason` text DEFAULT NULL,
  PRIMARY KEY (`leaveRequestId`),
  KEY `fk_leave_rider` (`riderId`),
  CONSTRAINT `fk_leave_rider` FOREIGN KEY (`riderId`) REFERENCES `Rider` (`riderId`)
) ENGINE=InnoDB AUTO_INCREMENT=41 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.LeaveRequestComment definition

CREATE TABLE `LeaveRequestComment` (
  `leaveRequestCommentId` int(11) NOT NULL AUTO_INCREMENT,
  `leaveRequestId` int(11) NOT NULL,
  `comment` text DEFAULT NULL,
  `roleId` int(11) NOT NULL,
  `createdAt` datetime NOT NULL,
  `createdBy` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`leaveRequestCommentId`),
  KEY `FK_LeaveRequestComment_LeaveRequest` (`leaveRequestId`),
  CONSTRAINT `FK_LeaveRequestComment_LeaveRequest` FOREIGN KEY (`leaveRequestId`) REFERENCES `LeaveRequest` (`leaveRequestId`)
) ENGINE=InnoDB AUTO_INCREMENT=75 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


-- CAG_Admin_Dev.OrderList definition

CREATE TABLE `OrderList` (
  `orderListId` bigint(20) NOT NULL AUTO_INCREMENT,
  `riderId` varchar(20) NOT NULL,
  `orderDate` date NOT NULL,
  `orderCount` int(11) NOT NULL,
  `createdAt` datetime NOT NULL DEFAULT current_timestamp(),
  `createdBy` varchar(20) NOT NULL,
  PRIMARY KEY (`orderListId`),
  UNIQUE KEY `uq_rider_date` (`riderId`,`orderDate`),
  CONSTRAINT `fk_rider_orderList` FOREIGN KEY (`riderId`) REFERENCES `Rider` (`riderId`)
) ENGINE=InnoDB AUTO_INCREMENT=1627 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- CAG_Admin_Dev.RiderVehicleConfig definition

CREATE TABLE `RiderVehicleConfig` (
  `riderVehicleConfigId` int(11) NOT NULL AUTO_INCREMENT,
  `riderId` varchar(20) DEFAULT NULL,
  `vehicleId` varchar(20) DEFAULT NULL,
  `status` tinyint(1) DEFAULT NULL,
  `startDate` datetime NOT NULL,
  `endDate` datetime DEFAULT NULL,
  PRIMARY KEY (`riderVehicleConfigId`),
  KEY `fk_ridervconfig_rider` (`riderId`),
  KEY `fk_ridervconfig_vehicle` (`vehicleId`),
  CONSTRAINT `fk_ridervconfig_rider` FOREIGN KEY (`riderId`) REFERENCES `Rider` (`riderId`),
  CONSTRAINT `fk_ridervconfig_vehicle` FOREIGN KEY (`vehicleId`) REFERENCES `Vehicle` (`vehicleId`)
) ENGINE=InnoDB AUTO_INCREMENT=59 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;