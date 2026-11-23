/*
  UNISPORT - xóa dữ liệu để nạp lại bộ dữ liệu bảo vệ.

  GIỮ toàn bộ bản ghi dbo.Role và các tài khoản dbo.[User] có vai trò
  Center Manager, trạng thái Active tại thời điểm bắt đầu giao dịch.
  XÓA các tài khoản còn lại và toàn bộ bản ghi trong các bảng người dùng khác
  của database đã chọn, bao gồm thanh toán, hoàn tiền, lịch sử, chat và OTP.

  Cấu trúc bảng, khóa ngoại, index và giá trị IDENTITY được giữ nguyên.
  Thứ tự xóa được tính từ khóa ngoại thực tế trong sys.foreign_keys.
  Mặc định @ThucHien = 0 chỉ hiển thị số bản ghi dự kiến xóa.

  Cách dùng trong SSMS
  1. Backup database, dừng backend và các tiến trình đang ghi dữ liệu.
  2. Chọn database cần dọn, đối chiếu @TenCSDL rồi chạy toàn bộ file ở chế độ 0.
  3. Kiểm tra tài khoản giữ lại và danh sách bảng, đổi @ThucHien = 1 rồi chạy lại.
  4. Chạy unisport_demo_dataset.sql để nạp dữ liệu mới.

  Khi @ThucHien = 1, mọi thao tác xóa nằm trong cùng một transaction.
  Nếu gặp lỗi, toàn bộ giao dịch được rollback. Có thể chạy lại sau khi sửa lỗi.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;

DECLARE @ThucHien BIT = 0;
DECLARE @TenCSDL sysname = N'swp391_demo_db';

IF DB_NAME() <> @TenCSDL
    THROW 51100, N'Đang chọn sai database. Đối chiếu database hiện tại và @TenCSDL.', 1;

IF @@TRANCOUNT <> 0
    THROW 51101, N'Hãy kết thúc giao dịch đang mở trước khi chạy file này.', 1;

DECLARE @BangRole INT = OBJECT_ID(N'dbo.Role', N'U');
DECLARE @BangUser INT = OBJECT_ID(N'dbo.[User]', N'U');

IF @BangRole IS NULL OR @BangUser IS NULL
    THROW 51102, N'Database phải có bảng dbo.Role và dbo.[User].', 1;

DECLARE @TaiKhoanGiu TABLE (User_ID INT PRIMARY KEY);
DECLARE @BangCanXoa TABLE (
    Object_ID INT PRIMARY KEY,
    TenSchema sysname NOT NULL,
    TenBang sysname NOT NULL,
    ThuTu INT NULL,
    SoDongTruoc BIGINT NULL,
    SoDongDaXoa BIGINT NULL,
    SoDongSau BIGINT NULL
);

DECLARE @SoRole BIGINT;
DECLARE @SoUser BIGINT;
DECLARE @SoTaiKhoanGiu BIGINT;
DECLARE @ObjectID INT;
DECLARE @TenDayDu NVARCHAR(517);
DECLARE @LenhSQL NVARCHAR(MAX);
DECLARE @SoDong BIGINT;
DECLARE @ThuTu INT = 0;

BEGIN TRY
    IF @ThucHien = 1
        BEGIN TRANSACTION;

    -- Khóa các tài khoản và vai trò trong chế độ ghi để tập tài khoản giữ lại ổn định.
    IF @ThucHien = 1
    BEGIN
        SELECT @SoRole = COUNT_BIG(*) FROM dbo.Role WITH (TABLOCKX, HOLDLOCK);
        SELECT @SoUser = COUNT_BIG(*) FROM dbo.[User] WITH (TABLOCKX, HOLDLOCK);
    END
    ELSE
    BEGIN
        SELECT @SoRole = COUNT_BIG(*) FROM dbo.Role;
        SELECT @SoUser = COUNT_BIG(*) FROM dbo.[User];
    END;

    INSERT @TaiKhoanGiu (User_ID)
    SELECT u.User_ID
    FROM dbo.[User] u
    JOIN dbo.Role r ON r.Role_ID = u.Role_ID
    WHERE LOWER(LTRIM(RTRIM(r.Role_Name))) = N'center manager'
      AND LOWER(LTRIM(RTRIM(u.Status))) = N'active';

    SELECT @SoTaiKhoanGiu = COUNT_BIG(*) FROM @TaiKhoanGiu;

    IF @SoTaiKhoanGiu = 0
        THROW 51103, N'Không có Center Manager đang Active để giữ lại và dùng khi nạp dữ liệu mới.', 1;

    -- Bảng Role được loại khỏi danh sách xóa. Bảng User được xử lý sau cùng.
    INSERT @BangCanXoa (Object_ID, TenSchema, TenBang)
    SELECT t.object_id, s.name, t.name
    FROM sys.tables t
    JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE t.is_ms_shipped = 0
      AND t.object_id <> @BangRole;

    -- Chọn bảng không còn bảng con chưa xử lý, bảo đảm xóa con trước cha.
    -- Khóa ngoại tự tham chiếu được kiểm tra trên toàn bộ câu DELETE bởi SQL Server.
    WHILE EXISTS (SELECT 1 FROM @BangCanXoa WHERE ThuTu IS NULL)
    BEGIN
        SET @ObjectID = NULL;

        SELECT TOP (1) @ObjectID = b.Object_ID
        FROM @BangCanXoa b
        WHERE b.ThuTu IS NULL
          AND (b.Object_ID <> @BangUser OR NOT EXISTS (
              SELECT 1 FROM @BangCanXoa khac
              WHERE khac.ThuTu IS NULL AND khac.Object_ID <> @BangUser
          ))
          AND NOT EXISTS (
              SELECT 1
              FROM sys.foreign_keys fk
              JOIN @BangCanXoa con ON con.Object_ID = fk.parent_object_id
              WHERE fk.referenced_object_id = b.Object_ID
                AND con.ThuTu IS NULL
                AND fk.parent_object_id <> fk.referenced_object_id
          )
        ORDER BY b.TenSchema, b.TenBang;

        IF @ObjectID IS NULL
            THROW 51104, N'Không xác định được thứ tự xóa do có vòng khóa ngoại hoặc User phụ thuộc bảng nghiệp vụ. Cần kiểm tra các quan hệ này.', 1;

        SET @ThuTu = @ThuTu + 1;
        UPDATE @BangCanXoa SET ThuTu = @ThuTu WHERE Object_ID = @ObjectID;
    END;

    -- Đếm chính xác và khóa các bảng trong chế độ ghi, trước khi xóa bất kỳ bản ghi nào.
    SET @ThuTu = 1;
    WHILE @ThuTu <= (SELECT COUNT(*) FROM @BangCanXoa)
    BEGIN
        SELECT @ObjectID = Object_ID,
               @TenDayDu = QUOTENAME(TenSchema) + N'.' + QUOTENAME(TenBang)
        FROM @BangCanXoa WHERE ThuTu = @ThuTu;

        SET @LenhSQL = N'SELECT @KetQua = COUNT_BIG(*) FROM ' + @TenDayDu
            + CASE WHEN @ThucHien = 1 THEN N' WITH (TABLOCKX, HOLDLOCK);' ELSE N';' END;
        EXEC sys.sp_executesql @LenhSQL, N'@KetQua BIGINT OUTPUT', @KetQua = @SoDong OUTPUT;
        UPDATE @BangCanXoa SET SoDongTruoc = @SoDong WHERE Object_ID = @ObjectID;
        SET @ThuTu = @ThuTu + 1;
    END;

    SELECT DB_NAME() AS DatabaseHienTai, @ThucHien AS ThucHien,
           @SoRole AS SoRoleGiuLai, @SoTaiKhoanGiu AS SoCenterManagerGiuLai,
           @SoUser - @SoTaiKhoanGiu AS SoTaiKhoanSeXoa;

    SELECT u.User_ID, u.Username, u.FullName, u.Email, r.Role_Name, u.Status
    FROM @TaiKhoanGiu g
    JOIN dbo.[User] u ON u.User_ID = g.User_ID
    JOIN dbo.Role r ON r.Role_ID = u.Role_ID
    ORDER BY u.User_ID;

    SELECT ThuTu, TenSchema, TenBang, SoDongTruoc,
           CASE WHEN Object_ID = @BangUser THEN SoDongTruoc - @SoTaiKhoanGiu
                ELSE SoDongTruoc END AS SoDongDuKienXoa
    FROM @BangCanXoa ORDER BY ThuTu;

    IF @ThucHien = 0
    BEGIN
        SELECT N'Đã xem trước. Đổi @ThucHien = 1 để xóa dữ liệu theo danh sách trên.' AS KetQua;
        RETURN;
    END;

    SET @ThuTu = 1;
    WHILE @ThuTu <= (SELECT COUNT(*) FROM @BangCanXoa)
    BEGIN
        SELECT @ObjectID = Object_ID,
               @TenDayDu = QUOTENAME(TenSchema) + N'.' + QUOTENAME(TenBang)
        FROM @BangCanXoa WHERE ThuTu = @ThuTu;

        IF @ObjectID = @BangUser
        BEGIN
            DELETE u FROM dbo.[User] u
            WHERE NOT EXISTS (SELECT 1 FROM @TaiKhoanGiu g WHERE g.User_ID = u.User_ID);
            SET @SoDong = ROWCOUNT_BIG();
        END
        ELSE
        BEGIN
            SET @LenhSQL = N'DELETE FROM ' + @TenDayDu + N'; SET @KetQua = ROWCOUNT_BIG();';
            EXEC sys.sp_executesql @LenhSQL, N'@KetQua BIGINT OUTPUT', @KetQua = @SoDong OUTPUT;
        END;

        UPDATE @BangCanXoa SET SoDongDaXoa = @SoDong WHERE Object_ID = @ObjectID;
        SET @ThuTu = @ThuTu + 1;
    END;

    -- Kiểm tra toàn bộ kết quả trước khi xác nhận giao dịch.
    SET @ThuTu = 1;
    WHILE @ThuTu <= (SELECT COUNT(*) FROM @BangCanXoa)
    BEGIN
        SELECT @ObjectID = Object_ID,
               @TenDayDu = QUOTENAME(TenSchema) + N'.' + QUOTENAME(TenBang)
        FROM @BangCanXoa WHERE ThuTu = @ThuTu;

        SET @LenhSQL = N'SELECT @KetQua = COUNT_BIG(*) FROM ' + @TenDayDu + N';';
        EXEC sys.sp_executesql @LenhSQL, N'@KetQua BIGINT OUTPUT', @KetQua = @SoDong OUTPUT;
        UPDATE @BangCanXoa SET SoDongSau = @SoDong WHERE Object_ID = @ObjectID;
        SET @ThuTu = @ThuTu + 1;
    END;

    IF EXISTS (SELECT 1 FROM @BangCanXoa WHERE Object_ID <> @BangUser AND SoDongSau <> 0)
        THROW 51105, N'Có bảng nghiệp vụ còn dữ liệu sau khi xóa. Toàn bộ giao dịch sẽ rollback.', 1;

    IF (SELECT COUNT_BIG(*) FROM dbo.Role) <> @SoRole
       OR (SELECT COUNT_BIG(*) FROM dbo.[User]) <> @SoTaiKhoanGiu
       OR EXISTS (
           SELECT 1 FROM @TaiKhoanGiu g
           LEFT JOIN dbo.[User] u ON u.User_ID = g.User_ID
           LEFT JOIN dbo.Role r ON r.Role_ID = u.Role_ID
           WHERE u.User_ID IS NULL
              OR LOWER(LTRIM(RTRIM(r.Role_Name))) <> N'center manager'
              OR LOWER(LTRIM(RTRIM(u.Status))) <> N'active'
       )
        THROW 51106, N'Số role hoặc tài khoản quản lý giữ lại không đúng. Toàn bộ giao dịch sẽ rollback.', 1;

    COMMIT TRANSACTION;

    SELECT N'Đã xóa dữ liệu. Role và các Center Manager đang Active đã được giữ lại. Có thể nạp bộ dữ liệu mới.' AS KetQua;
    SELECT ThuTu, TenSchema, TenBang, SoDongTruoc, SoDongDaXoa, SoDongSau
    FROM @BangCanXoa ORDER BY ThuTu;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
