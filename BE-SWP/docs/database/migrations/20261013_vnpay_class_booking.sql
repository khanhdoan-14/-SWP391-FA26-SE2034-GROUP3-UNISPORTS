-- Run manually against the existing SQL Server swp391_db before starting this backend.
-- Times are DATETIME2(0) in Asia/Ho_Chi_Minh (UTC+07:00).
SET XACT_ABORT ON;
BEGIN TRANSACTION;

ALTER TABLE dbo.Class_Booking DROP CONSTRAINT CK_Booking_Status;
ALTER TABLE dbo.Class_Booking WITH CHECK ADD CONSTRAINT CK_Booking_Status
    CHECK (Status IN (N'Pending', N'Booked', N'Cancelled', N'Completed'));

ALTER TABLE dbo.Class_Booking ADD Payment_Expires_At DATETIME2(0) NULL,
    Payment_Method NVARCHAR(20) NULL;
GO

ALTER TABLE dbo.Class_Booking ADD CONSTRAINT CK_Booking_Payment_Method
    CHECK (Payment_Method IS NULL OR Payment_Method IN (N'PACKAGE', N'DIRECT'));

ALTER TABLE dbo.Payment ADD Expires_At DATETIME2(0) NULL,
    Vnp_Transaction_No NVARCHAR(15) NULL,
    Vnp_Response_Code NVARCHAR(2) NULL,
    Vnp_Transaction_Status NVARCHAR(2) NULL,
    Vnp_Pay_Date NVARCHAR(14) NULL,
    Requires_Review BIT NOT NULL CONSTRAINT DF_Payment_Requires_Review DEFAULT 0 WITH VALUES;

CREATE INDEX IX_Booking_Pending_Expiry ON dbo.Class_Booking (Status, Payment_Expires_At) INCLUDE (Session_ID);
COMMIT TRANSACTION;


USE [swp391_db];
GO

SELECT c.name AS ColumnName, TYPE_NAME(c.user_type_id) AS DataType
FROM sys.columns c
WHERE c.object_id IN (OBJECT_ID('dbo.Class_Booking'), OBJECT_ID('dbo.Payment'))
  AND c.name IN (
      'Payment_Expires_At', 'Payment_Method',
      'Expires_At', 'Vnp_Transaction_No',
      'Vnp_Response_Code', 'Vnp_Transaction_Status',
      'Vnp_Pay_Date', 'Requires_Review'
  );

SELECT name AS ConstraintName
FROM sys.objects
WHERE name IN (
    'CK_Booking_Payment_Method',
    'DF_Payment_Requires_Review'
);

SELECT name AS IndexName
FROM sys.indexes
WHERE object_id = OBJECT_ID('dbo.Class_Booking')
  AND name = 'IX_Booking_Pending_Expiry';