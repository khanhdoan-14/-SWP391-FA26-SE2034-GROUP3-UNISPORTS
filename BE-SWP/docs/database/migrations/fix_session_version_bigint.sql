-- Run this once against swp391_db if dbo.User.Session_Version is still INT.
-- Preserves the existing default constraint name and expression, if present.
SET XACT_ABORT ON;

USE [swp391_db];
GO

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @tableId INT = OBJECT_ID(N'dbo.[User]', N'U');
    DECLARE @columnId INT;
    DECLARE @typeName SYSNAME;
    DECLARE @defaultName SYSNAME;
    DECLARE @defaultDefinition NVARCHAR(MAX);
    DECLARE @sql NVARCHAR(MAX);

    IF @tableId IS NULL
        THROW 51001, N'Table dbo.User was not found in swp391_db.', 1;

    SELECT
        @columnId = c.column_id,
        @typeName = t.name
    FROM sys.columns AS c
    JOIN sys.types AS t ON t.user_type_id = c.user_type_id
    WHERE c.object_id = @tableId
      AND c.name = N'Session_Version';

    IF @columnId IS NULL
        THROW 51002, N'Column Session_Version was not found in dbo.User.', 1;

    IF @typeName <> N'bigint'
    BEGIN
        SELECT
            @defaultName = dc.name,
            @defaultDefinition = dc.definition
        FROM sys.default_constraints AS dc
        WHERE dc.parent_object_id = @tableId
          AND dc.parent_column_id = @columnId;

        IF @defaultName IS NOT NULL
        BEGIN
            SET @sql = N'ALTER TABLE dbo.[User] DROP CONSTRAINT ' + QUOTENAME(@defaultName) + N';';
            EXEC sys.sp_executesql @sql;
        END;

        ALTER TABLE dbo.[User]
            ALTER COLUMN [Session_Version] BIGINT NOT NULL;

        IF @defaultName IS NOT NULL
        BEGIN
            SET @sql = N'ALTER TABLE dbo.[User] ADD CONSTRAINT ' + QUOTENAME(@defaultName)
                + N' DEFAULT ' + @defaultDefinition + N' FOR [Session_Version];';
            EXEC sys.sp_executesql @sql;
        END;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT DB_NAME() AS CurrentDatabase, TYPE_NAME(c.user_type_id) AS DataType
FROM sys.columns AS c
WHERE c.object_id = OBJECT_ID(N'dbo.[User]', N'U')
  AND c.name = N'Session_Version';
