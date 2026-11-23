/*
  UNISPORT - bộ dữ liệu bảo vệ SWP391, SQL Server (schema backend 20261110)
  Mac dinh chi XEM truoc (@ThucHien = 0); khong sua du lieu.
  Sau khi doc ket qua va sao luu DB phục vụ bảo vệ, doi thanh 1 de ap dung mot lan.
  Giữ Admin/Center Manager, lich su giao dich va du lieu hien co.
  Mặc định KHÔNG vô hiệu hóa tài khoản cũ (@VoHieuHoaTaiKhoanCu = 0).
  Tai khoan cu van nam trong DB; lop cu van gan Coach cu.
  Khong chay tren DB that; dung ghi vao DB tu ung dung trong khi chay.
  Yeu cau schema theo backend hien tai va migrations lien quan da ap dung.
  Neu gap loi, kiem tra giao dich trong cung session: IF @@TRANCOUNT > 0 ROLLBACK;
  Sau ROLLBACK, SQL Server van co the da tang gia tri IDENTITY.
  Mật khẩu chung: Test2026@. Email example.com la du lieu gia.
  Email giả đã xác minh chỉ dành cho trình bày đăng nhập; không dùng để trình bày gửi OTP.
  @NgayBaoVe mặc định là ngày Việt Nam lúc chạy; có thể nhập ngày bảo vệ thật.
  Chạy một lần trên DB phục vụ bảo vệ, backup sau khi seed; restore backup trước mỗi lần diễn tập.
  Pending hết hạn sau 15 phút; trạng thái có thể thay đổi khi backend xử lý lifecycle.
  Giao dịch trong script là dữ liệu giả lập, không chứng minh callback ngân hàng thật.
  Kịch bản: member01 mua mới; 02 dùng gói; 03 sai môn; 04 thiếu thời hạn;
  05 hủy/hoàn tiền trực tiếp; 06 bảo lưu; 09 xem lịch sử tập với coach06.
  Các truy vấn cuối file chỉ tổng hợp dữ liệu mới; dashboard ứng dụng gồm cả DB cũ.
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

DECLARE @ThucHien BIT = 0; -- 0: chi xem du lieu du kien; 1: ghi vao DB
DECLARE @TenCSDL sysname = N'swp391_demo_db'; -- doi neu DB phục vụ bảo vệ cua ban co ten khac
DECLARE @VoHieuHoaTaiKhoanCu BIT = 0; -- 1: vô hiệu hóa Member/Coach/Receptionist cũ đang Active
DECLARE @NgayBaoVe DATE = CONVERT(DATE, DATEADD(HOUR, 7, SYSUTCDATETIME()));
DECLARE @BayGio DATETIME2(0) = DATEADD(HOUR, 7, SYSUTCDATETIME());
-- Neo cả ngày lẫn giờ theo ngày bảo vệ, giữ đúng quan hệ thời gian khi đổi ngày.
SET @BayGio = DATEADD(DAY, DATEDIFF(DAY, CONVERT(DATE, @BayGio), @NgayBaoVe), @BayGio);
DECLARE @Hash VARCHAR(255) = '$2a$10$h6x8QaJNcge.RFcqWsBrP.WrAnQ5npv3qSUbtqSATyyech6/FtKbi';
-- Thứ Hai cách ngày bảo vệ 7..13 ngày: luôn đủ cửa sổ hủy > 3 ngày.
DECLARE @ThuHai DATE = DATEADD(DAY,
    7 + (7 - (DATEDIFF(DAY, CONVERT(DATE, '19000101', 112), @NgayBaoVe) % 7 + 7) % 7) % 7,
    @NgayBaoVe);

DECLARE @Mon TABLE (
    STT INT PRIMARY KEY, Ten NVARCHAR(100) NOT NULL, Nhom VARCHAR(12) NOT NULL,
    DanhMuc NVARCHAR(50) NOT NULL, LoaiPhong NVARCHAR(30) NOT NULL,
    TenPhong NVARCHAR(100) NOT NULL,
    Subject_ID INT NULL
);
INSERT INTO @Mon (STT, Ten, Nhom, DanhMuc, LoaiPhong, TenPhong) VALUES
(1,N'Gym','FITNESS',N'Fitness',N'GYM',N'Phòng Gym 1'),
(2,N'Pilates','FITNESS',N'Fitness',N'PILATES',N'Phòng Pilates 1'),
(3,N'Boxing','MARTIAL',N'Võ Thuật',N'BOXING',N'Phòng Võ 1'),
(4,N'Vovinam','MARTIAL',N'Võ Thuật',N'MARTIAL_ARTS',N'Phòng Võ 2'),
(5,N'Karate','MARTIAL',N'Võ Thuật',N'MARTIAL_ARTS',N'Phòng Võ 3'),
(6,N'Judo','MARTIAL',N'Võ Thuật',N'MARTIAL_ARTS',N'Phòng Võ 4'),
(7,N'Muay Thái','MARTIAL',N'Võ Thuật',N'MARTIAL_ARTS',N'Phòng Võ 5'),
(8,N'Taekwondo','MARTIAL',N'Võ Thuật',N'MARTIAL_ARTS',N'Phòng Võ 6'),
(9,N'Bơi','SPORT',N'Thể thao dưới nước',N'SWIMMING_POOL',N'Hồ bơi 1'),
(10,N'Bóng Đá','SPORT',N'Thể thao trên cạn',N'FOOTBALL_COURT',N'Sân Bóng Đá 1'),
(11,N'Bóng Rổ','SPORT',N'Thể thao trên cạn',N'BASKETBALL_COURT',N'Sân Bóng Rổ 1'),
(12,N'Cầu Lông','SPORT',N'Thể thao trên cạn',N'BADMINTON_COURT',N'Sân Cầu Lông 1'),
(13,N'Bóng Bàn','SPORT',N'Thể thao trên cạn',N'TABLE_TENNIS_COURT',N'Sân Bóng Bàn 1'),
(14,N'Tennis','SPORT',N'Thể thao trên cạn',N'TENNIS_COURT',N'Sân Tennis 1'),
(15,N'HIIT','FITNESS',N'Fitness',N'GYM',N'Phòng Gym 2'),
(16,N'Yoga','FITNESS',N'Fitness',N'MULTIPURPOSE',N'Phòng Đa Năng 1'),
(17,N'Zumba','FITNESS',N'Dance',N'MULTIPURPOSE',N'Phòng Đa Năng 2');

DECLARE @TaiKhoan TABLE (
    STT INT NOT NULL, VaiTro NVARCHAR(50) NOT NULL,
    Username VARCHAR(50) NOT NULL PRIMARY KEY, Email VARCHAR(100) NOT NULL,
    FullName NVARCHAR(100) NOT NULL, Phone VARCHAR(15) NULL
);
;WITH So AS (
    SELECT 1 AS n UNION ALL SELECT n + 1 FROM So WHERE n < 30
)
INSERT INTO @TaiKhoan (STT, VaiTro, Username, Email, FullName)
SELECT n, r.VaiTro, r.Prefix + RIGHT('00' + CAST(n AS VARCHAR(2)), 2),
       'unisport.' + r.Prefix + RIGHT('00' + CAST(n AS VARCHAR(2)), 2) + '@example.com',
       r.Ten + N' ' + RIGHT('00' + CAST(n AS VARCHAR(2)), 2)
FROM So CROSS JOIN (VALUES
    (N'Member','member',N'Hội viên',30),
    (N'Coach','coach',N'Huấn luyện viên',10),
    (N'Receptionist','receptionist',N'Lễ tân',4)
) AS r(VaiTro,Prefix,Ten,SoLuong)
WHERE n <= r.SoLuong OPTION (MAXRECURSION 30);

-- So dien thoai gia lap, tao ngau nhien va giu co dinh trong file.
UPDATE a SET Phone = p.Phone
FROM @TaiKhoan a JOIN (VALUES
('member01','0325968925'),
('member02','0988616412'),
('member03','0845621870'),
('member04','0810191631'),
('member05','0978195952'),
('member06','0908197184'),
('member07','0860224913'),
('member08','0356755194'),
('member09','0780941262'),
('member10','0948365643'),
('member11','0336111074'),
('member12','0898803918'),
('member13','0323773103'),
('member14','0389170814'),
('member15','0828461937'),
('member16','0811275747'),
('member17','0947595582'),
('member18','0787483867'),
('member19','0382414656'),
('member20','0969286603'),
('member21','0765298153'),
('member22','0764828985'),
('member23','0368521807'),
('member24','0906564260'),
('member25','0361249235'),
('member26','0342135156'),
('member27','0773324938'),
('member28','0893176944'),
('member29','0787004840'),
('member30','0356193061'),
('coach01','0857200363'),
('coach02','0837754709'),
('coach03','0338589687'),
('coach04','0824077339'),
('coach05','0707239438'),
('coach06','0988535851'),
('coach07','0397962427'),
('coach08','0814182853'),
('coach09','0375121159'),
('coach10','0888230471'),
('receptionist01','0789112191'),
('receptionist02','0363905986'),
('receptionist03','0860755430'),
('receptionist04','0796513305')
) p(Username,Phone) ON p.Username=a.Username;

UPDATE a SET FullName = n.Ten
FROM @TaiKhoan a JOIN (VALUES
(1,N'Nguyễn Minh Anh'),(2,N'Trần Hoàng Nam'),(3,N'Lê Thu Hà'),(4,N'Phạm Gia Huy'),
(5,N'Võ Ngọc Mai'),(6,N'Đặng Đức Anh'),(7,N'Bùi Thanh Tâm'),(8,N'Đỗ Khánh Linh'),
(9,N'Nguyễn Hải Yến'),(10,N'Trần Quốc Bảo'),(11,N'Lê Minh Quân'),(12,N'Phạm Bảo Ngọc'),
(13,N'Hoàng Tuấn Kiệt'),(14,N'Vũ Phương Anh'),(15,N'Đặng Nhật Minh'),(16,N'Bùi Thảo Vy'),
(17,N'Đỗ Anh Khoa'),(18,N'Ngô Ngọc Hân'),(19,N'Dương Đức Phúc'),(20,N'Lý Minh Châu'),
(21,N'Trương Gia Bảo'),(22,N'Đinh Thanh Trúc'),(23,N'Phan Thành Đạt'),(24,N'Mai Hà My'),
(25,N'Hồ Trung Hiếu'),(26,N'Cao Bích Ngọc'),(27,N'Tạ Quang Huy'),(28,N'Lâm Yến Nhi'),
(29,N'Huỳnh Khánh Duy'),(30,N'Châu Kim Ngân')
) n(STT,Ten) ON a.STT=n.STT WHERE a.VaiTro=N'Member';

UPDATE a SET FullName = n.Ten
FROM @TaiKhoan a JOIN (VALUES
(N'Coach',1,N'Nguyễn Thành Long'),(N'Coach',2,N'Trần Mỹ Linh'),
(N'Coach',3,N'Lê Quốc Hùng'),(N'Coach',4,N'Phạm Thanh Sơn'),
(N'Coach',5,N'Võ Minh Tuấn'),(N'Coach',6,N'Đặng Hồng Nhung'),
(N'Coach',7,N'Bùi Anh Dũng'),(N'Coach',8,N'Đỗ Hoàng Phúc'),
(N'Coach',9,N'Ngô Tuấn Anh'),(N'Coach',10,N'Dương Quốc Việt'),
(N'Receptionist',1,N'Nguyễn Thu Trang'),(N'Receptionist',2,N'Trần Ngọc Ánh'),
(N'Receptionist',3,N'Lê Bảo Trâm'),(N'Receptionist',4,N'Phạm Hồng Hạnh')
) n(VaiTro,STT,Ten) ON a.VaiTro=n.VaiTro AND a.STT=n.STT;

DECLARE @TinhHuong TABLE (STT INT PRIMARY KEY, MoTa NVARCHAR(300));
INSERT @TinhHuong VALUES
(1,N'Minh Anh: chưa có gói/đăng ký; mua gói Fitness rồi đăng ký Yoga trong buổi trình bày.'),
(2,N'Hoàng Nam: Fitness còn hạn đủ khóa; đăng ký Yoga bằng PACKAGE.'),
(3,N'Thu Hà: chỉ có Fitness; không được dùng gói để đăng ký Bơi.'),
(4,N'Gia Huy: gói Thể thao sắp hết hạn, không phủ buổi cuối Bơi.'),
(5,N'Ngọc Mai: đã trả trực tiếp lớp Yoga; hủy > 3 ngày, hoàn 50%, quản lý duyệt, lễ tân chi.'),
(6,N'Đức Anh: gói 6 tháng còn quyền bảo lưu, không có lịch đăng ký cản trở.'),
(7,N'Thanh Tâm: gói hết hạn, không được đăng ký bằng PACKAGE.'),
(8,N'Khánh Linh: đang bảo lưu từ 5 ngày trước; kích hoạt lại để xem cộng số ngày thực tế.'),
(9,N'Hải Yến: lớp Yoga đang học; điểm danh, kế hoạch và đánh giá; đăng nhập coach06.'),
(10,N'Quốc Bảo: lớp Bơi đã kết thúc, có lịch sử tập và gói hết hạn.'),
(11,N'Minh Quân: giao dịch mua gói Failed, subscription Cancelled.'),
(12,N'Bảo Ngọc: giao dịch mua gói Pending, tự hết hạn sau 15 phút.'),
(13,N'Tuấn Kiệt: hoàn tiền PENDING, quản lý có thể duyệt.'),
(14,N'Phương Anh: hoàn tiền APPROVED, đã có mã nhận tiền mặt tại quầy.'),
(15,N'Nhật Minh: hoàn tiền PAID, có chứng từ chi và lịch sử.'),
(16,N'Thảo Vy: yêu cầu hoàn REJECTED có ghi chú; tiền thanh toán gốc vẫn Paid.'),
(17,N'Anh Khoa: đăng ký trực tiếp Failed/Cancelled; không chiếm chỗ.'),
(18,N'Ngọc Hân: đăng ký trực tiếp Pending, giữ chỗ 15 phút.'),
(19,N'Đức Phúc: đã đăng ký lớp Cầu Lông đầy.'),
(20,N'Minh Châu: đã đăng ký lớp Cầu Lông đầy.'),
(21,N'Gia Bảo: đã đăng ký lớp Cầu Lông đầy.'),
(22,N'Thanh Trúc: đã đăng ký Tennis gần đầy (còn 1 chỗ).'),
(23,N'Thành Đạt: đã đăng ký Tennis gần đầy (còn 1 chỗ).'),
(24,N'Hà My: đã đăng ký Tennis gần đầy (còn 1 chỗ).');

DECLARE @Goi TABLE (
    Ten NVARCHAR(100) PRIMARY KEY, Nhom VARCHAR(12), Gia DECIMAL(12,2),
    SoNgay INT, BaoLuu INT
);
INSERT @Goi VALUES
(N'Fitness 3 tháng','FITNESS',1500000,90,0),
(N'Võ thuật 3 tháng','MARTIAL',1800000,90,0),
(N'Thể thao 3 tháng','SPORT',2000000,90,0),
(N'Toàn diện 6 tháng','ALL',3900000,180,1),
(N'Toàn diện 12 tháng','ALL',7200000,365,2);

DECLARE @LichLop TABLE (
    Ten NVARCHAR(100) PRIMARY KEY, MonSTT INT, CoachSTT INT, Ngay DATE,
    SoTuan INT, Gio TIME(0), SucChua INT, TrangThai NVARCHAR(20)
);
INSERT @LichLop
SELECT Ten, STT, (STT-1)%10+1, @ThuHai, 8,
       CASE WHEN STT<=10 THEN CAST('07:00' AS TIME) ELSE CAST('09:30' AS TIME) END,
       CASE WHEN STT=12 THEN 3 WHEN STT=14 THEN 4 ELSE 20 END, N'Active'
FROM @Mon;
INSERT @LichLop VALUES
(N'Yoga cân bằng',16,6,DATEADD(DAY,-28,@ThuHai),8,'16:00',12,N'Active'),
(N'Bơi cơ bản',9,9,DATEADD(DAY,-84,@ThuHai),8,'16:00',12,N'Completed');
-- Keep existing Boxing/HIIT classes intact when adding this demo set to an existing DB.
UPDATE @LichLop SET Ten = Ten + N' Demo' WHERE Ten IN (N'Boxing', N'HIIT');

DECLARE @Mua TABLE (
    MemberSTT INT PRIMARY KEY, TenGoi NVARCHAR(100), NgayBatDau DATE,
    TrangThai NVARCHAR(20), ThanhToan NVARCHAR(20)
);
INSERT @Mua VALUES
(2,N'Fitness 3 tháng',DATEADD(DAY,-10,@NgayBaoVe),N'Active',N'Paid'),
(3,N'Fitness 3 tháng',DATEADD(DAY,-10,@NgayBaoVe),N'Active',N'Paid'),
(4,N'Thể thao 3 tháng',DATEADD(DAY,-86,@NgayBaoVe),N'Active',N'Paid'),
(6,N'Toàn diện 6 tháng',DATEADD(DAY,-20,@NgayBaoVe),N'Active',N'Paid'),
(7,N'Fitness 3 tháng',DATEADD(DAY,-105,@NgayBaoVe),N'Expired',N'Paid'),
(8,N'Toàn diện 6 tháng',DATEADD(DAY,-40,@NgayBaoVe),N'Frozen',N'Paid'),
(9,N'Fitness 3 tháng',DATEADD(DAY,-35,@ThuHai),N'Active',N'Paid'),
(10,N'Thể thao 3 tháng',DATEADD(DAY,-119,@ThuHai),N'Expired',N'Paid'),
(11,N'Fitness 3 tháng',@NgayBaoVe,N'Cancelled',N'Failed'),
(12,N'Fitness 3 tháng',@NgayBaoVe,N'Pending',N'Pending'),
(25,N'Fitness 3 tháng',DATEADD(DAY,-105,@NgayBaoVe),N'Expired',N'Paid'),
(26,N'Võ thuật 3 tháng',DATEADD(MONTH,-1,DATEFROMPARTS(YEAR(@NgayBaoVe),MONTH(@NgayBaoVe),1)),N'Active',N'Paid'),
(27,N'Toàn diện 12 tháng',DATEADD(MONTH,-2,DATEFROMPARTS(YEAR(@NgayBaoVe),MONTH(@NgayBaoVe),1)),N'Active',N'Paid'),
(28,N'Thể thao 3 tháng',DATEADD(MONTH,-1,DATEFROMPARTS(YEAR(@NgayBaoVe),MONTH(@NgayBaoVe),1)),N'Active',N'Paid'),
(29,N'Fitness 3 tháng',DATEFROMPARTS(YEAR(@NgayBaoVe),MONTH(@NgayBaoVe),1),N'Active',N'Paid'),
(30,N'Võ thuật 3 tháng',DATEFROMPARTS(YEAR(@NgayBaoVe),MONTH(@NgayBaoVe),1),N'Active',N'Paid');

DECLARE @DangKy TABLE (
    MemberSTT INT PRIMARY KEY, TenLop NVARCHAR(100), CachTra NVARCHAR(20),
    TrangThai NVARCHAR(20), ThanhToan NVARCHAR(20), HoanTien VARCHAR(20) NULL,
    NgayDat DATETIME2(0), Ma VARCHAR(36) NULL
);
INSERT @DangKy (MemberSTT,TenLop,CachTra,TrangThai,ThanhToan,HoanTien,NgayDat) VALUES
(5,N'Yoga',N'DIRECT',N'Booked',N'Paid',NULL,DATEADD(DAY,-3,@BayGio)),
(9,N'Yoga cân bằng',N'PACKAGE',N'Booked',NULL,NULL,CAST(DATEADD(DAY,-29,@ThuHai) AS DATETIME2(0))),
(10,N'Bơi cơ bản',N'PACKAGE',N'Completed',NULL,NULL,CAST(DATEADD(DAY,-85,@ThuHai) AS DATETIME2(0))),
(13,N'Yoga',N'DIRECT',N'Cancelled',N'Paid','PENDING',DATEADD(DAY,-5,@BayGio)),
(14,N'Yoga',N'DIRECT',N'Cancelled',N'Paid','APPROVED',DATEADD(DAY,-5,@BayGio)),
(15,N'Yoga',N'DIRECT',N'Cancelled',N'Paid','PAID',DATEADD(DAY,-5,@BayGio)),
(16,N'Yoga',N'DIRECT',N'Cancelled',N'Paid','REJECTED',DATEADD(DAY,-5,@BayGio)),
(17,N'Boxing Demo',N'DIRECT',N'Cancelled',N'Failed',NULL,DATEADD(DAY,-1,@BayGio)),
(18,N'Boxing Demo',N'DIRECT',N'Pending',N'Pending',NULL,@BayGio),
(19,N'Cầu Lông',N'DIRECT',N'Booked',N'Paid',NULL,DATEADD(DAY,-2,@BayGio)),
(20,N'Cầu Lông',N'DIRECT',N'Booked',N'Paid',NULL,DATEADD(DAY,-2,@BayGio)),
(21,N'Cầu Lông',N'DIRECT',N'Booked',N'Paid',NULL,DATEADD(DAY,-2,@BayGio)),
(22,N'Tennis',N'DIRECT',N'Booked',N'Paid',NULL,DATEADD(DAY,-2,@BayGio)),
(23,N'Tennis',N'DIRECT',N'Booked',N'Paid',NULL,DATEADD(DAY,-2,@BayGio)),
(24,N'Tennis',N'DIRECT',N'Booked',N'Paid',NULL,DATEADD(DAY,-2,@BayGio)),
(25,N'Yoga cân bằng',N'DIRECT',N'Booked',N'Paid',NULL,CAST(DATEADD(DAY,-29,@ThuHai) AS DATETIME2(0))),
(26,N'Yoga cân bằng',N'DIRECT',N'Booked',N'Paid',NULL,CAST(DATEADD(DAY,-29,@ThuHai) AS DATETIME2(0))),
(27,N'Bơi cơ bản',N'DIRECT',N'Completed',N'Paid',NULL,CAST(DATEADD(DAY,-85,@ThuHai) AS DATETIME2(0))),
(28,N'Gym',N'DIRECT',N'Booked',N'Paid',NULL,DATEADD(DAY,-3,@BayGio)),
(29,N'Pilates',N'DIRECT',N'Booked',N'Paid',NULL,DATEADD(DAY,-3,@BayGio)),
(30,N'Muay Thái',N'DIRECT',N'Booked',N'Paid',NULL,DATEADD(DAY,-3,@BayGio));
-- UUID xác định cho từng đăng ký; một mã gồm toàn bộ 16 buổi của một khóa.
UPDATE @DangKy SET Ma='39100000-0000-4000-8000-'+RIGHT('000000000000'+CAST(MemberSTT AS VARCHAR(12)),12);

IF @ThucHien = 0
BEGIN
    SELECT N'XEM TRƯỚC: chưa thay đổi dữ liệu; chưa kiểm tra toàn bộ schema/trùng tên.' AS ThongBao,
           DB_NAME() AS CSDLHienTai, @TenCSDL AS CSDLSeApDung, @NgayBaoVe AS NgayBaoVe,
           @ThuHai AS NgayBatDau, @VoHieuHoaTaiKhoanCu AS VoHieuHoaTaiKhoanCu;
    SELECT r.Role_Name, u.Status, COUNT(*) AS SoTaiKhoanHienCo
    FROM dbo.[User] u JOIN dbo.Role r ON r.Role_ID=u.Role_ID
    GROUP BY r.Role_Name, u.Status ORDER BY r.Role_Name, u.Status;
    -- Chỉ là danh sách ảnh hưởng nếu chủ động bật vô hiệu hóa tài khoản cũ.
    SELECT c.Class_ID, c.Name AS TenLopCu, u.Username AS CoachCu, MIN(s.[Date]) AS BuoiGanNhatTuHomNay
    FROM dbo.[Class] c JOIN dbo.[User] u ON u.User_ID=c.Coach_ID
    JOIN dbo.Role r ON r.Role_ID=u.Role_ID JOIN dbo.Class_Session s ON s.Class_ID=c.Class_ID
    WHERE LOWER(LTRIM(RTRIM(r.Role_Name)))=N'coach' AND LOWER(LTRIM(RTRIM(u.Status)))=N'active'
      AND @VoHieuHoaTaiKhoanCu=1
      AND c.Status IN (N'Active',N'Open') AND s.Status=N'Scheduled' AND s.[Date]>=@NgayBaoVe
    GROUP BY c.Class_ID, c.Name, u.Username ORDER BY BuoiGanNhatTuHomNay, c.Class_ID;
    SELECT VaiTro, COUNT(*) AS SoTaiKhoan FROM @TaiKhoan GROUP BY VaiTro;
    SELECT STT, Ten AS Mon, DanhMuc, LoaiPhong, TenPhong AS TenPhongSan,
           Ten AS TenLop,
           CASE WHEN STT <= 10 THEN '07:00-08:30' ELSE '09:30-11:00' END AS KhungGio,
           'coach' + RIGHT('00' + CAST(((STT - 1) % 10 + 1) AS VARCHAR(2)), 2) AS Coach
    FROM @Mon ORDER BY STT;
    SELECT Ten, Gia, SoNgay, BaoLuu FROM @Goi ORDER BY Gia;
    SELECT VaiTro, Username, Email, FullName, Phone FROM @TaiKhoan ORDER BY VaiTro, STT;
    SELECT a.Username,a.FullName,t.MoTa FROM @TinhHuong t JOIN @TaiKhoan a ON a.STT=t.STT AND a.VaiTro=N'Member' ORDER BY t.STT;
    SELECT * FROM @LichLop ORDER BY Ngay,Ten;
    SELECT m.*,DATEADD(DAY,g.SoNgay-1,m.NgayBatDau) AS NgayHetHan FROM @Mua m JOIN @Goi g ON g.Ten=m.TenGoi ORDER BY MemberSTT;
    SELECT * FROM @DangKy ORDER BY MemberSTT;
    SELECT 44 AS TaiKhoan,19 AS Lop,304 AS BuoiHoc,5 AS Goi,16 AS GoiDaMua,
           21 AS LuotDangKy,336 AS BookingTheoBuoi,35 AS GiaoDich,4 AS YeuCauHoan;
    RETURN;
END;

IF DB_NAME() <> @TenCSDL
    THROW 51012, N'Đang chọn sai database. Kiểm tra DB hiện tại và @TenCSDL.', 1;
IF @@TRANCOUNT <> 0
    THROW 51015, N'Hãy kết thúc giao dịch đang mở trước khi chạy script dữ liệu mẫu.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.[User]', N'U') IS NULL OR OBJECT_ID(N'dbo.Role', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Subject', N'U') IS NULL OR OBJECT_ID(N'dbo.Subject_Room_Type', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Room', N'U') IS NULL OR OBJECT_ID(N'dbo.[Class]', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Class_Session', N'U') IS NULL OR OBJECT_ID(N'dbo.Membership_Package', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Package_Included_Sport', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Membership_Included_Sport', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Member_Subscription', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Class_Booking', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Payment', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Attendance', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Training_Result', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Training_Plan', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Training_Exercise', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Training_Plan_Recipient', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Training_Exercise_Result', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Member_Notification', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Refund_Request', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Refund_Session', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Activity_Log', N'U') IS NULL
       THROW 51000, N'Thiếu bảng cần thiết. Hãy kiểm tra schema và migrations.', 1;
    IF COL_LENGTH(N'dbo.[User]', N'Email_Verified') IS NULL OR COL_LENGTH(N'dbo.[User]', N'Auth_Provider') IS NULL
       OR COL_LENGTH(N'dbo.Subject', N'Status') IS NULL
       OR COL_LENGTH(N'dbo.Room', N'Room_Type') IS NULL OR COL_LENGTH(N'dbo.Room', N'Location') IS NULL
       OR COL_LENGTH(N'dbo.[Class]', N'Duration_Weeks') IS NULL OR COL_LENGTH(N'dbo.[Class]', N'Has_PT') IS NULL
       OR COL_LENGTH(N'dbo.Membership_Package', N'Discount') IS NULL OR COL_LENGTH(N'dbo.Membership_Package', N'Freeze_Months') IS NULL
       THROW 51001, N'Thiếu cột cần thiết. Hãy kiểm tra schema và migrations.', 1;
    IF COL_LENGTH(N'dbo.Member_Subscription',N'Price_At_Purchase') IS NULL
       OR COL_LENGTH(N'dbo.Member_Subscription',N'Freeze_Months_At_Purchase') IS NULL
       OR COL_LENGTH(N'dbo.Payment',N'Created_At') IS NULL
       OR COL_LENGTH(N'dbo.Payment',N'Paid_At') IS NULL
       OR COL_LENGTH(N'dbo.Payment',N'Requires_Review') IS NULL
       OR COL_LENGTH(N'dbo.Training_Plan',N'Plan_Scope') IS NULL
       OR COL_LENGTH(N'dbo.Training_Result',N'Progress_Status') IS NULL
       OR COL_LENGTH(N'dbo.Refund_Request',N'Refund_Policy') IS NULL
       OR COL_LENGTH(N'dbo.Refund_Request',N'Pickup_Code') IS NULL
       THROW 51013, N'Thiếu schema mua gói/bảo lưu/tài chính/kế hoạch tập/hoàn tiền hiện tại.', 1;
    IF COL_LENGTH(N'dbo.Membership_Package',N'Included_Classes') IS NOT NULL
       THROW 51014, N'Cần áp dụng migration unlimited_membership rồi drop_membership_session_quota trước khi seed.', 1;
    IF (SELECT COUNT(*) FROM dbo.Role WHERE LOWER(LTRIM(RTRIM(Role_Name))) IN (N'member',N'coach',N'receptionist')) <> 3
       OR EXISTS (SELECT 1 FROM dbo.Role WHERE LOWER(LTRIM(RTRIM(Role_Name))) IN (N'member',N'coach',N'receptionist')
                  GROUP BY LOWER(LTRIM(RTRIM(Role_Name))) HAVING COUNT(*) <> 1)
       THROW 51002, N'Cần đúng một Role cho mỗi vai trò Member, Coach, Receptionist.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.[User] u JOIN dbo.Role r ON r.Role_ID=u.Role_ID
                   WHERE LOWER(LTRIM(RTRIM(r.Role_Name)))=N'center manager' AND u.Status=N'Active')
       THROW 51003, N'Cần tài khoản Center Manager đang Active để trình bày duyệt hoàn tiền.', 1;
    IF EXISTS (SELECT 1 FROM dbo.[User] u JOIN dbo.Role r ON r.Role_ID=u.Role_ID
               WHERE LOWER(LTRIM(RTRIM(u.Username))) = 'admin'
                 AND LOWER(LTRIM(RTRIM(r.Role_Name))) IN (N'member',N'coach',N'receptionist'))
       THROW 51004, N'Username admin có vai trò thuộc diện thay thế. Cần kiểm tra thủ công.', 1;
    IF EXISTS (SELECT 1 FROM @TaiKhoan s JOIN dbo.[User] u
               ON LOWER(u.Username)=LOWER(s.Username) OR LOWER(u.Email)=LOWER(s.Email))
       THROW 51005, N'Tên đăng nhập/email trong bộ dữ liệu đã tồn tại. Script chỉ được chạy một lần.', 1;
    IF EXISTS (SELECT 1 FROM @TaiKhoan a JOIN dbo.[User] u ON u.Phone=a.Phone)
       THROW 51022, N'Số điện thoại trong bộ dữ liệu đã tồn tại. Hãy đổi số bị trùng trước khi chạy.', 1;
    IF EXISTS (SELECT 1 FROM @DangKy d JOIN dbo.Class_Booking b ON b.Registration_Code=d.Ma)
       THROW 51021,N'Mã đăng ký trong bộ dữ liệu đã tồn tại. Không ghép lịch sử cũ vào dữ liệu mới.',1;
    IF EXISTS (SELECT 1 FROM @Mon m JOIN dbo.Subject s
               ON LTRIM(RTRIM(s.Name)) COLLATE Latin1_General_100_CI_AI = m.Ten COLLATE Latin1_General_100_CI_AI
               GROUP BY m.STT HAVING COUNT(*) > 1)
       THROW 51006, N'Có nhiều môn cũ trùng tên khi bỏ dấu; hãy kiểm tra thủ công.', 1;
    IF EXISTS (SELECT 1 FROM @Mon m JOIN dbo.Subject s
               ON LTRIM(RTRIM(s.Name)) COLLATE Latin1_General_100_CI_AI = m.Ten COLLATE Latin1_General_100_CI_AI
               WHERE ISNULL(s.Status,N'') <> N'Active')
       THROW 51007, N'Môn trùng tên đang không Active. Hãy kiểm tra trước khi chạy.', 1;
    IF EXISTS (SELECT 1 FROM @Mon m JOIN dbo.Room r ON r.Name = m.TenPhong)
       OR EXISTS (SELECT 1 FROM @LichLop l JOIN dbo.[Class] c ON c.Name=l.Ten)
       OR EXISTS (SELECT 1 FROM @Goi g JOIN dbo.Membership_Package p ON p.Name = g.Ten)
       THROW 51008, N'Tên phòng, lớp hoặc gói trong bộ dữ liệu đã tồn tại. Không ghi đè dữ liệu cũ.', 1;

    -- Không xóa dữ liệu cũ; chỉ vô hiệu hóa khi người chạy bật tùy chọn rõ ràng.
    UPDATE u SET u.Status = N'Inactive'
    FROM dbo.[User] u JOIN dbo.Role r ON r.Role_ID = u.Role_ID
    WHERE @VoHieuHoaTaiKhoanCu=1 AND LOWER(LTRIM(RTRIM(r.Role_Name))) IN (N'member',N'coach',N'receptionist')
      AND LOWER(LTRIM(RTRIM(u.Status))) = N'active';

    INSERT dbo.[User] (Role_ID,FullName,Username,Phone,Email,Password,Status,Email_Verified,Auth_Provider)
    SELECT r.Role_ID,a.FullName,a.Username,a.Phone,a.Email,@Hash,N'Active',1,N'LOCAL'
    FROM @TaiKhoan a JOIN dbo.Role r ON LOWER(LTRIM(RTRIM(r.Role_Name))) = LOWER(a.VaiTro);

    INSERT dbo.Subject (Name, Description, Category, Status)
    SELECT m.Ten, N'Môn thể thao được tổ chức tại trung tâm UNISPORT.', m.DanhMuc, N'Active'
    FROM @Mon m WHERE NOT EXISTS (
        SELECT 1 FROM dbo.Subject s WHERE LTRIM(RTRIM(s.Name)) COLLATE Latin1_General_100_CI_AI = m.Ten COLLATE Latin1_General_100_CI_AI
    );
    UPDATE m SET Subject_ID = s.Subject_ID FROM @Mon m JOIN dbo.Subject s
      ON LTRIM(RTRIM(s.Name)) COLLATE Latin1_General_100_CI_AI = m.Ten COLLATE Latin1_General_100_CI_AI;
    IF (SELECT COUNT(DISTINCT Subject_ID) FROM @Mon) <> 17
       THROW 51009, N'Không thể ánh xạ đủ 17 môn khác nhau.', 1;

    INSERT dbo.Subject_Room_Type (Subject_ID, Room_Type)
    SELECT m.Subject_ID, m.LoaiPhong FROM @Mon m
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Subject_Room_Type t WHERE t.Subject_ID=m.Subject_ID AND t.Room_Type=m.LoaiPhong);

    INSERT dbo.Room (Name, Max_Capacity, Room_Type, Location, Status)
    SELECT TenPhong, 20, LoaiPhong, N'Khu thể thao UNISPORT', N'Active' FROM @Mon;

    DECLARE @LopMoi TABLE (Class_ID INT PRIMARY KEY, Ten NVARCHAR(100));
    INSERT dbo.[Class] (Subject_ID,Coach_ID,Room_ID,Name,Max_Capacity,Status,[Date],Duration_Weeks,End_Date,
                        Price,Days_Of_Week,Start_Time,End_Time,Has_PT)
    OUTPUT inserted.Class_ID, inserted.Name INTO @LopMoi
    SELECT m.Subject_ID,u.User_ID,r.Room_ID,l.Ten,l.SucChua,l.TrangThai,l.Ngay,l.SoTuan,
           DATEADD(DAY,7*l.SoTuan-1,l.Ngay),100000,N'T2, T4',l.Gio,DATEADD(MINUTE,90,l.Gio),
           CASE WHEN m.STT=1 THEN 1 ELSE 0 END
    FROM @LichLop l JOIN @Mon m ON m.STT=l.MonSTT JOIN dbo.Room r ON r.Name=m.TenPhong
    JOIN dbo.[User] u ON u.Username='coach'+RIGHT('00'+CAST(l.CoachSTT AS VARCHAR(2)),2);
    IF (SELECT COUNT(*) FROM @LopMoi) <> 19 THROW 51010, N'Không tạo đủ 19 lớp.', 1;

    INSERT dbo.Class_Session (Class_ID,[Date],Start_Time,End_Time,Status)
    SELECT c.Class_ID, DATEADD(DAY,7*w.n+d.n,c.[Date]), c.Start_Time,c.End_Time,
           CASE WHEN DATEADD(DAY,7*w.n+d.n,c.[Date])<@NgayBaoVe THEN N'Completed' ELSE N'Scheduled' END
    FROM @LopMoi l JOIN dbo.[Class] c ON c.Class_ID=l.Class_ID
    CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7)) w(n)
    CROSS JOIN (VALUES (0),(2)) d(n);

    DECLARE @GoiMoi TABLE (Package_ID INT PRIMARY KEY, Ten NVARCHAR(100));
    INSERT dbo.Membership_Package (Name,Description,Price,Duration,Discount,Freeze_Months,Benefits,Term_Conditions,Status)
    OUTPUT inserted.Package_ID, inserted.Name INTO @GoiMoi
    SELECT Ten,N'Gói tập luyện tại trung tâm UNISPORT.',Gia,SoNgay,0,BaoLuu,
           N'Quyền tập theo môn và thời hạn, không giới hạn số buổi; phải đăng ký lớp còn chỗ.',
           N'Áp dụng cho các môn được cấu hình trong gói và trong thời hạn hiệu lực.'
           +CASE WHEN BaoLuu>0 THEN N' Trong thời gian bảo lưu, quyền lợi gói tạm dừng. Quyền bảo lưu đã chọn không được hoàn lại khi tham gia lại sớm. Ngày hết hạn chỉ cộng số ngày bảo lưu thực tế đủ 24 giờ.' ELSE N'' END,
           N'Active' FROM @Goi;
    INSERT dbo.Package_Included_Sport (Package_ID,Subject_ID)
    SELECT p.Package_ID,m.Subject_ID FROM @GoiMoi p JOIN @Goi g ON g.Ten=p.Ten
    CROSS JOIN @Mon m WHERE g.Nhom='ALL' OR g.Nhom=m.Nhom;

    -- 1. Gói đã mua và quyền môn được chụp tại thời điểm mua; không seed quota/MIXED.
    DECLARE @HoiVien TABLE (STT INT PRIMARY KEY, User_ID INT UNIQUE);
    INSERT @HoiVien SELECT a.STT,u.User_ID FROM @TaiKhoan a JOIN dbo.[User] u ON u.Username=a.Username WHERE a.VaiTro=N'Member';
    DECLARE @LeTan INT=(SELECT User_ID FROM dbo.[User] WHERE Username='receptionist01');
    DECLARE @QuanLy INT=(SELECT TOP (1) u.User_ID FROM dbo.[User] u JOIN dbo.Role r ON r.Role_ID=u.Role_ID
                        WHERE LOWER(LTRIM(RTRIM(r.Role_Name)))=N'center manager' AND u.Status=N'Active' ORDER BY u.User_ID);
    DECLARE @Subscription TABLE (Subscription_ID INT PRIMARY KEY, User_ID INT UNIQUE);
    INSERT dbo.Member_Subscription
        (User_ID,Package_ID,Start_Date,End_Date,Status,Price_At_Purchase,Duration_At_Purchase,
         Terms_At_Purchase,Package_Name_At_Purchase,Created_At,Cancellation_Reason,Cancelled_At,
         Freeze_Months_At_Purchase,Freeze_Months_Used,Freeze_Started_At,Freeze_Ends_At)
    OUTPUT inserted.Subscription_ID,inserted.User_ID INTO @Subscription
    SELECT h.User_ID,p.Package_ID,m.NgayBatDau,DATEADD(DAY,g.SoNgay-1,m.NgayBatDau),m.TrangThai,
           g.Gia,g.SoNgay,p.Term_Conditions,p.Name,CAST(m.NgayBatDau AS DATETIME2(0)),
           CASE WHEN m.TrangThai=N'Cancelled' THEN N'Thanh toán thất bại, hủy đơn mua gói.' END,
           CASE WHEN m.TrangThai=N'Cancelled' THEN @BayGio END,
           g.BaoLuu,CASE WHEN m.TrangThai=N'Frozen' THEN 1 ELSE 0 END,
           CASE WHEN m.TrangThai=N'Frozen' THEN DATEADD(DAY,-5,@BayGio) END,
           CASE WHEN m.TrangThai=N'Frozen' THEN DATEADD(MONTH,1,DATEADD(DAY,-5,@BayGio)) END
    FROM @Mua m JOIN @HoiVien h ON h.STT=m.MemberSTT JOIN @Goi g ON g.Ten=m.TenGoi
    JOIN dbo.Membership_Package p ON p.Name=g.Ten;

    INSERT dbo.Membership_Included_Sport (Subscription_ID,Subject_ID,Subject_Name_At_Purchase)
    SELECT s.Subscription_ID,pis.Subject_ID,sub.Name FROM @Subscription s
    JOIN dbo.Member_Subscription ms ON ms.Subscription_ID=s.Subscription_ID
    JOIN dbo.Package_Included_Sport pis ON pis.Package_ID=ms.Package_ID
    JOIN dbo.Subject sub ON sub.Subject_ID=pis.Subject_ID;

    DECLARE @ThanhToanMoi TABLE (Payment_ID INT PRIMARY KEY, Subscription_ID INT NULL, Booking_ID INT NULL);
    INSERT dbo.Payment
        (Subscription_ID,Receptionist_ID,Payment_Type,Amount,Method,Payment_Date,Status,
         Discount_Amount,Expires_At,Requires_Review,Item_Name_At_Payment,Created_At,Paid_At)
    OUTPUT inserted.Payment_ID,inserted.Subscription_ID,inserted.Booking_ID INTO @ThanhToanMoi
    SELECT s.Subscription_ID,CASE WHEN m.ThanhToan=N'Paid' THEN @LeTan END,N'Subscription',g.Gia,
           CASE WHEN m.ThanhToan=N'Paid' THEN N'Cash' ELSE N'E_Wallet' END,
           CASE WHEN m.ThanhToan=N'Paid' THEN CAST(m.NgayBatDau AS DATETIME2(0)) ELSE @BayGio END,
           m.ThanhToan,0,CASE WHEN m.ThanhToan=N'Pending' THEN DATEADD(MINUTE,15,@BayGio) END,
           0,g.Ten,CAST(m.NgayBatDau AS DATETIME2(0)),
           CASE WHEN m.ThanhToan=N'Paid' THEN CAST(m.NgayBatDau AS DATETIME2(0)) END
    FROM @Mua m JOIN @HoiVien h ON h.STT=m.MemberSTT JOIN @Subscription s ON s.User_ID=h.User_ID
    JOIN @Goi g ON g.Ten=m.TenGoi;

    -- 2. Một đăng ký khóa gồm 16 booking, nhưng chỉ một Payment tham chiếu booking đầu.
    INSERT dbo.Class_Booking (User_ID,Session_ID,Booking_Datetime,Status,Payment_Expires_At,Payment_Method,Registration_Code)
    SELECT h.User_ID,s.Session_ID,d.NgayDat,d.TrangThai,
           CASE WHEN d.TrangThai=N'Pending' THEN DATEADD(MINUTE,15,@BayGio) END,d.CachTra,d.Ma
    FROM @DangKy d JOIN @HoiVien h ON h.STT=d.MemberSTT JOIN @LopMoi l ON l.Ten=d.TenLop
    JOIN dbo.Class_Session s ON s.Class_ID=l.Class_ID;

    INSERT dbo.Payment
        (Booking_ID,Receptionist_ID,Payment_Type,Amount,Method,Payment_Date,Status,Discount_Amount,
         Expires_At,Requires_Review,Item_Name_At_Payment,Created_At,Paid_At)
    OUTPUT inserted.Payment_ID,inserted.Subscription_ID,inserted.Booking_ID INTO @ThanhToanMoi
    SELECT b.Booking_ID,CASE WHEN d.ThanhToan=N'Paid' THEN @LeTan END,N'Class_Booking',c.Price*n.SoBuoi,
           CASE WHEN d.ThanhToan=N'Paid' THEN N'Cash' ELSE N'E_Wallet' END,
           d.NgayDat,d.ThanhToan,0,
           CASE WHEN d.ThanhToan=N'Pending' THEN DATEADD(MINUTE,15,@BayGio) END,
           CASE WHEN d.HoanTien IN ('PENDING','APPROVED') THEN 1 ELSE 0 END,c.Name,d.NgayDat,
           CASE WHEN d.ThanhToan=N'Paid' THEN d.NgayDat END
    FROM @DangKy d JOIN @LopMoi l ON l.Ten=d.TenLop JOIN dbo.[Class] c ON c.Class_ID=l.Class_ID
    CROSS APPLY (SELECT TOP (1) cb.Booking_ID FROM dbo.Class_Booking cb JOIN dbo.Class_Session cs ON cs.Session_ID=cb.Session_ID
                 WHERE cb.Registration_Code=d.Ma ORDER BY cs.[Date],cs.Start_Time,cb.Booking_ID) b
    CROSS APPLY (SELECT COUNT(*) AS SoBuoi FROM dbo.Class_Booking cb WHERE cb.Registration_Code=d.Ma) n
    WHERE d.CachTra=N'DIRECT';

    -- 3. Bốn hồ sơ hủy độc lập ở các bước; member05 còn nguyên để thao tác hủy trực tiếp.
    -- Payment gốc vẫn Paid sau khi chi hoàn, đúng hành vi RefundService hiện tại.
    DECLARE @HoanMoi TABLE (Refund_ID INT PRIMARY KEY, Payment_ID INT UNIQUE);
    INSERT dbo.Refund_Request
        (Payment_ID,Requested_By,Item_Name,Paid_Amount,Estimated_Amount,Approved_Amount,
         Total_Sessions,Cancelled_Sessions,Status,Reason,Refund_Policy,Review_Note,Reviewed_By,Reviewed_At,
         Payout_Method,Pickup_Code,Payout_Reference,Payout_Note,Paid_By,Paid_At,
         Created_At,Updated_At,Notification_Revision,Read_Revision,Version)
    OUTPUT inserted.Refund_ID,inserted.Payment_ID INTO @HoanMoi
    SELECT p.Payment_ID,h.User_ID,d.TenLop,p.Amount,FLOOR(p.Amount/2),
           CASE WHEN d.HoanTien IN ('APPROVED','PAID') THEN FLOOR(p.Amount/2) END,
           16,16,d.HoanTien,N'Hội viên hủy trước buổi đầu hơn 3 ngày.', 'CLASS_CANCEL_50',
           CASE WHEN d.HoanTien='REJECTED' THEN N'Hồ sơ cần xác minh lại thông tin trước khi hoàn tiền.'
                WHEN d.HoanTien IN ('APPROVED','PAID') THEN N'Duyệt hoàn 50% số tiền thực thu theo chính sách.' END,
           CASE WHEN d.HoanTien<>'PENDING' THEN @QuanLy END,
           CASE WHEN d.HoanTien<>'PENDING' THEN DATEADD(DAY,-2,@BayGio) END,
           CASE WHEN d.HoanTien IN ('APPROVED','PAID') THEN 'CASH' END,
           CASE WHEN d.HoanTien IN ('APPROVED','PAID') THEN 'HT-UNISPORT-'+CAST(d.MemberSTT AS VARCHAR(2)) END,
           CASE WHEN d.HoanTien='PAID' THEN N'CASH-HT-UNISPORT-15' END,
           CASE WHEN d.HoanTien='PAID' THEN N'Đã chi tiền mặt tại quầy.' END,
           CASE WHEN d.HoanTien='PAID' THEN @LeTan END,
           CASE WHEN d.HoanTien='PAID' THEN DATEADD(DAY,-1,@BayGio) END,
           DATEADD(DAY,-3,@BayGio),DATEADD(DAY,-1,@BayGio),
           CASE WHEN d.HoanTien='PENDING' THEN 1 WHEN d.HoanTien='PAID' THEN 3 ELSE 2 END,0,0
    FROM @DangKy d JOIN @HoiVien h ON h.STT=d.MemberSTT
    JOIN dbo.Class_Booking b ON b.Registration_Code=d.Ma
    JOIN @ThanhToanMoi t ON t.Booking_ID=b.Booking_ID JOIN dbo.Payment p ON p.Payment_ID=t.Payment_ID
    WHERE d.HoanTien IS NOT NULL;

    INSERT dbo.Refund_Session (Refund_ID,Position,Session_ID,Session_Date,Start_Time,Refundable)
    SELECT r.Refund_ID,ROW_NUMBER() OVER (PARTITION BY r.Refund_ID ORDER BY s.[Date],s.Start_Time),
           s.Session_ID,s.[Date],s.Start_Time,1
    FROM @HoanMoi r JOIN dbo.Payment p ON p.Payment_ID=r.Payment_ID
    JOIN dbo.Class_Booking firstBooking ON firstBooking.Booking_ID=p.Booking_ID
    JOIN dbo.Class_Booking b ON b.Registration_Code=firstBooking.Registration_Code
    JOIN dbo.Class_Session s ON s.Session_ID=b.Session_ID;

    -- 4. Lịch sử tập: chỉ điểm danh/đánh giá các buổi đã qua và học viên đã đăng ký.
    INSERT dbo.Attendance (Session_ID,User_ID,Status,Note)
    SELECT s.Session_ID,b.User_ID,
           CASE WHEN h.STT=26 AND s.[Date]=(SELECT MIN(cs.[Date]) FROM dbo.Class_Session cs WHERE cs.Class_ID=s.Class_ID)
                THEN N'Absent' WHEN h.STT=25 THEN N'Late' ELSE N'Present' END,
           CASE WHEN h.STT=26 THEN N'Đã ghi nhận tình trạng tham gia buổi tập.' ELSE N'Tham gia buổi tập theo lịch.' END
    FROM dbo.Class_Booking b JOIN @HoiVien h ON h.User_ID=b.User_ID
    JOIN dbo.Class_Session s ON s.Session_ID=b.Session_ID JOIN @LopMoi l ON l.Class_ID=s.Class_ID
    WHERE s.[Date]<@NgayBaoVe AND b.Status IN (N'Booked',N'Completed')
      -- Chừa buổi gần nhất của Hải Yến để HLV thực hiện điểm danh rồi tạo đánh giá mới.
      AND NOT (h.STT=9 AND s.[Date]=(SELECT MAX(cs.[Date]) FROM dbo.Class_Session cs
                                   WHERE cs.Class_ID=s.Class_ID AND cs.[Date]<@NgayBaoVe));

    INSERT dbo.Training_Result
        (Session_ID,User_ID,Coach_ID,Metric,Training_Content,Progress_Status,Next_Steps,Coach_Feedback,[Date],Updated_At,Is_Withdrawn,Version)
    SELECT a.Session_ID,a.User_ID,c.Coach_ID,
           CASE WHEN c.Subject_ID=(SELECT Subject_ID FROM @Mon WHERE STT=9) THEN N'Hoàn thành 4 lượt bơi 25m, nghỉ 60 giây giữa lượt.'
                ELSE N'Giữ thăng bằng 30 giây mỗi bên; hoàn thành 3 hiệp bài tập.' END,
           CASE WHEN c.Subject_ID=(SELECT Subject_ID FROM @Mon WHERE STT=9) THEN N'Khởi động, kiểm soát nhịp thở và kỹ thuật bơi cơ bản.'
                ELSE N'Khởi động, kỹ thuật hít thở, tư thế cơ bản và thả lỏng.' END,
           CASE WHEN s.[Date]=c.[Date] THEN 'INITIAL' ELSE 'IMPROVING' END,
           N'Tập đúng kỹ thuật, tăng thời lượng từ từ ở buổi tiếp theo.',N'Có tiến bộ, tiếp tục duy trì lịch tập.',
           s.[Date],DATEADD(HOUR,18,CAST(s.[Date] AS DATETIME2(0))),0,0
    FROM dbo.Attendance a JOIN @HoiVien h ON h.User_ID=a.User_ID
    JOIN dbo.Class_Session s ON s.Session_ID=a.Session_ID JOIN @LopMoi l ON l.Class_ID=s.Class_ID
    JOIN dbo.[Class] c ON c.Class_ID=s.Class_ID WHERE a.Status=N'Present';

    DECLARE @KeHoach TABLE (Plan_ID INT PRIMARY KEY,Class_ID INT UNIQUE);
    INSERT dbo.Training_Plan
        (Coach_ID,Member_ID,Plan_Scope,Class_ID,Title,Goal,Description,Assessment,Start_Date,End_Date,
         Status,Published_Revision,Read_Revision,Published_At,Created_At,Updated_At,Version)
    OUTPUT inserted.Plan_ID,inserted.Class_ID INTO @KeHoach
    SELECT c.Coach_ID,NULL,'CLASS',c.Class_ID,
           CASE WHEN c.Status=N'Completed' THEN N'Bơi cơ bản - tổng kết khóa' ELSE N'Yoga - cải thiện thăng bằng và nhịp thở' END,
           N'Nắm vững kỹ thuật cơ bản, duy trì lịch tập và theo dõi tiến bộ.',N'Kế hoạch rèn luyện kỹ thuật và theo dõi tiến bộ của học viên trong khóa học.',
           N'Học viên có trình độ mới bắt đầu.',c.[Date],c.End_Date,
           CASE WHEN c.Status=N'Completed' THEN 'COMPLETED' ELSE 'ASSIGNED' END,
           1,0,CAST(c.[Date] AS DATETIME2(0)),CAST(c.[Date] AS DATETIME2(0)),CAST(c.[Date] AS DATETIME2(0)),0
    FROM dbo.[Class] c JOIN @LopMoi l ON l.Class_ID=c.Class_ID
    WHERE l.Ten IN (N'Yoga cân bằng',N'Bơi cơ bản');

    INSERT dbo.Training_Plan_Recipient (Plan_ID,Member_ID,Read_Revision,Coach_Feedback)
    SELECT DISTINCT k.Plan_ID,b.User_ID,CASE WHEN h.STT=9 THEN 0 ELSE 1 END,N'Duy trì kỹ thuật và tiến độ theo kế hoạch.'
    FROM @KeHoach k JOIN dbo.Class_Session s ON s.Class_ID=k.Class_ID
    JOIN dbo.Class_Booking b ON b.Session_ID=s.Session_ID JOIN @HoiVien h ON h.User_ID=b.User_ID
    WHERE b.Status IN (N'Booked',N'Completed');

    INSERT dbo.Training_Exercise (Plan_ID,Position,Training_Date,Name,Instructions,Target,Completed)
    SELECT k.Plan_ID,n.STT,DATEADD(DAY,CASE n.STT WHEN 1 THEN 0 WHEN 2 THEN 2 ELSE 7 END,c.[Date]),
           CASE n.STT WHEN 1 THEN N'Khởi động và kiểm soát nhịp thở' WHEN 2 THEN N'Luyện kỹ thuật cơ bản' ELSE N'Phối hợp động tác' END,
           N'Thực hiện chậm, đúng kỹ thuật theo hướng dẫn của HLV.',N'3 hiệp, mỗi hiệp 10 lần',0
    FROM @KeHoach k JOIN dbo.[Class] c ON c.Class_ID=k.Class_ID CROSS JOIN (VALUES(1),(2),(3)) n(STT);

    INSERT dbo.Training_Exercise_Result (Recipient_ID,Exercise_ID,Completed,Member_Result)
    SELECT r.Recipient_ID,e.Exercise_ID,CASE WHEN h.STT=9 AND e.Position=3 THEN 0 ELSE 1 END,
           CASE WHEN h.STT=9 AND e.Position=3 THEN N'Cần luyện thêm trước khi xác nhận hoàn thành.' ELSE N'Đã hoàn thành theo hướng dẫn.' END
    FROM @KeHoach k JOIN dbo.Training_Plan_Recipient r ON r.Plan_ID=k.Plan_ID
    JOIN @HoiVien h ON h.User_ID=r.Member_ID JOIN dbo.Training_Exercise e ON e.Plan_ID=k.Plan_ID;

    INSERT dbo.Member_Notification
        (Member_ID,Type,Title,Message,Reference_Type,Reference_ID,Source_Key,Read_At,Created_At)
    SELECT r.Member_ID,'TRAINING_PLAN_ASSIGNED',N'Bạn vừa nhận bài tập: '+p.Title,
           N'HLV đã giao kế hoạch tập luyện cho lớp '+c.Name+N'.','TRAINING_PLAN',p.Plan_ID,
           'TRAINING_PLAN:'+CAST(p.Plan_ID AS VARCHAR(12))+':1:'+CAST(r.Member_ID AS VARCHAR(12)),
           CASE WHEN r.Read_Revision=1 THEN p.Published_At END,p.Published_At
    FROM @KeHoach k JOIN dbo.Training_Plan p ON p.Plan_ID=k.Plan_ID
    JOIN dbo.Training_Plan_Recipient r ON r.Plan_ID=k.Plan_ID JOIN dbo.[Class] c ON c.Class_ID=k.Class_ID;

    INSERT dbo.Member_Notification (Member_ID,Type,Title,Message,Reference_Type,Reference_ID,Source_Key,Created_At)
    SELECT ms.User_ID,'PACKAGE_EXPIRING',N'Gói dịch vụ sắp hết hạn',
           N'Gói '+ms.Package_Name_At_Purchase+N' còn '+CAST(DATEDIFF(DAY,@NgayBaoVe,ms.End_Date) AS NVARCHAR(10))+N' ngày.',
           'MEMBERSHIP',ms.Subscription_ID,
           'PACKAGE_EXPIRING:'+CAST(ms.Subscription_ID AS VARCHAR(12))+':'+CONVERT(VARCHAR(10),ms.End_Date,23),@BayGio
    FROM @Subscription s JOIN dbo.Member_Subscription ms ON ms.Subscription_ID=s.Subscription_ID
    WHERE ms.Status=N'Active' AND ms.End_Date BETWEEN @NgayBaoVe AND DATEADD(DAY,7,@NgayBaoVe);

    -- Lịch sử hoạt động được tạo cùng dữ liệu mẫu, theo ngày giao dịch tương ứng.
    INSERT dbo.Activity_Log (User_ID,Action_Type,Target_Entity,Description,Created_At)
    SELECT @LeTan,N'CONFIRM_PAYMENT',N'Payment',N'Ghi nhận thu tiền: '+p.Item_Name_At_Payment,p.Payment_Date
    FROM @ThanhToanMoi t JOIN dbo.Payment p ON p.Payment_ID=t.Payment_ID WHERE p.Status=N'Paid';
    INSERT dbo.Activity_Log (User_ID,Action_Type,Target_Entity,Description,Created_At)
    SELECT CASE WHEN r.Status='PENDING' THEN r.Requested_By WHEN r.Status='PAID' THEN @LeTan ELSE @QuanLy END,
           CASE WHEN r.Status='PENDING' THEN N'REQUEST_REFUND' WHEN r.Status='PAID' THEN N'PAY_REFUND' ELSE N'REVIEW_REFUND' END,
           N'Refund_Request',N'Hồ sơ hoàn tiền: '+r.Status,r.Updated_At
    FROM @HoanMoi h JOIN dbo.Refund_Request r ON r.Refund_ID=h.Refund_ID;

    IF (SELECT COUNT(*) FROM @GoiMoi) <> 5 OR
       (SELECT COUNT(*) FROM dbo.Class_Session s JOIN @LopMoi l ON l.Class_ID=s.Class_ID) <> 304
       THROW 51011, N'Số gói hoặc buổi học không đúng dự kiến.', 1;

    -- 5. Kiểm tra bất biến trước COMMIT; lỗi bất kỳ sẽ rollback toàn bộ lần seed.
    IF (SELECT COUNT(*) FROM dbo.[User] u JOIN @TaiKhoan a ON a.Username=u.Username)<>44
       OR (SELECT COUNT(*) FROM @Subscription)<>16 OR (SELECT COUNT(*) FROM @ThanhToanMoi)<>35
       OR (SELECT COUNT(*) FROM @HoanMoi)<>4 OR (SELECT COUNT(*) FROM @KeHoach)<>2
       OR (SELECT COUNT(*) FROM dbo.Class_Booking b JOIN @DangKy d ON d.Ma=b.Registration_Code)<>336
       THROW 51016,N'Số tài khoản/gói đã mua/giao dịch/hoàn tiền/kế hoạch/booking không đúng.',1;

    IF EXISTS (
        SELECT s.Session_ID FROM dbo.Class_Session s JOIN @LopMoi l ON l.Class_ID=s.Class_ID
        JOIN dbo.[Class] c ON c.Class_ID=s.Class_ID JOIN dbo.Class_Booking b ON b.Session_ID=s.Session_ID
        WHERE b.Status=N'Booked' OR (b.Status=N'Pending' AND b.Payment_Expires_At>@BayGio)
        GROUP BY s.Session_ID,c.Max_Capacity HAVING COUNT(DISTINCT b.User_ID)>c.Max_Capacity
    ) THROW 51017,N'Booking vượt sức chứa lớp.',1;

    IF EXISTS (
        SELECT 1 FROM @DangKy d JOIN @HoiVien h ON h.STT=d.MemberSTT
        JOIN @LopMoi l ON l.Ten=d.TenLop JOIN dbo.[Class] c ON c.Class_ID=l.Class_ID
        WHERE d.CachTra=N'PACKAGE' AND NOT EXISTS (
            SELECT 1 FROM @Subscription sm JOIN dbo.Member_Subscription ms ON ms.Subscription_ID=sm.Subscription_ID
            JOIN dbo.Membership_Included_Sport mis ON mis.Subscription_ID=ms.Subscription_ID AND mis.Subject_ID=c.Subject_ID
            WHERE ms.User_ID=h.User_ID AND ms.Status IN (N'Active',N'Expired')
              AND ms.Start_Date<=c.[Date] AND ms.End_Date>=(SELECT MAX(s.[Date]) FROM dbo.Class_Session s WHERE s.Class_ID=c.Class_ID)
        )
    ) THROW 51018,N'Đăng ký PACKAGE thiếu snapshot môn hoặc không đủ thời hạn.',1;

    IF EXISTS (
        SELECT 1 FROM dbo.Class_Session s JOIN @LopMoi l ON l.Class_ID=s.Class_ID
        JOIN dbo.Class_Session other ON other.Class_ID<>s.Class_ID AND other.[Date]=s.[Date]
             AND other.Start_Time<s.End_Time AND s.Start_Time<other.End_Time
        JOIN @LopMoi otherNew ON otherNew.Class_ID=other.Class_ID
        JOIN dbo.[Class] c ON c.Class_ID=s.Class_ID JOIN dbo.[Class] oc ON oc.Class_ID=other.Class_ID
        WHERE c.Coach_ID=oc.Coach_ID OR c.Room_ID=oc.Room_ID
    ) THROW 51019,N'Lịch lớp trong bộ dữ liệu trùng HLV hoặc phòng.',1;

    IF EXISTS (
        SELECT 1 FROM @HoanMoi h JOIN dbo.Refund_Request r ON r.Refund_ID=h.Refund_ID
        WHERE (SELECT COUNT(*) FROM dbo.Refund_Session rs WHERE rs.Refund_ID=r.Refund_ID)<>r.Total_Sessions
           OR r.Estimated_Amount<>FLOOR(r.Paid_Amount/2)
    ) THROW 51020,N'Snapshot buổi học hoặc số tiền hoàn không nhất quán.',1;

    COMMIT TRANSACTION;
    SELECT N'Đã tạo bộ dữ liệu bảo vệ: 44 tài khoản, 19 lớp/304 buổi, 5 gói, 16 subscription, 336 booking, 35 payment, 4 refund.' AS KetQua,
           @NgayBaoVe AS NgayBaoVe,@ThuHai AS NgayBatDauLopMoi;
    SELECT r.Role_Name,u.Username,u.FullName,u.Phone,u.Email,u.Status,u.Email_Verified
    FROM dbo.[User] u JOIN dbo.Role r ON r.Role_ID=u.Role_ID JOIN @TaiKhoan a ON a.Username=u.Username
    ORDER BY r.Role_Name,u.Username;
    SELECT p.Ten, COUNT(*) AS SoMon FROM @GoiMoi p JOIN dbo.Package_Included_Sport x ON x.Package_ID=p.Package_ID
    GROUP BY p.Ten ORDER BY p.Ten;
    SELECT u.Username,u.FullName,t.MoTa FROM @TinhHuong t JOIN @HoiVien h ON h.STT=t.STT
    JOIN dbo.[User] u ON u.User_ID=h.User_ID ORDER BY t.STT;
    SELECT u.Username,ms.Subscription_ID,ms.Package_Name_At_Purchase,ms.Status,ms.Start_Date,ms.End_Date,
           ms.Freeze_Months_At_Purchase,ms.Freeze_Months_Used
    FROM @Subscription s JOIN dbo.Member_Subscription ms ON ms.Subscription_ID=s.Subscription_ID
    JOIN dbo.[User] u ON u.User_ID=ms.User_ID ORDER BY u.Username;
    SELECT c.Class_ID,c.Name,c.Status,c.Max_Capacity,co.Username AS Coach,c.[Date],c.End_Date,
           (SELECT COUNT(DISTINCT b.User_ID) FROM dbo.Class_Booking b JOIN dbo.Class_Session s ON s.Session_ID=b.Session_ID
            WHERE s.Class_ID=c.Class_ID AND (b.Status=N'Booked' OR (b.Status=N'Pending' AND b.Payment_Expires_At>@BayGio))) AS DangGiuCho
    FROM @LopMoi l JOIN dbo.[Class] c ON c.Class_ID=l.Class_ID JOIN dbo.[User] co ON co.User_ID=c.Coach_ID ORDER BY c.Name;
    SELECT r.Refund_ID,u.Username,r.Status,r.Paid_Amount,r.Estimated_Amount,r.Approved_Amount,r.Pickup_Code
    FROM @HoanMoi h JOIN dbo.Refund_Request r ON r.Refund_ID=h.Refund_ID
    JOIN dbo.[User] u ON u.User_ID=r.Requested_By ORDER BY u.Username;
    -- Đối chiếu dashboard hiện tại: SUM(Amount) với Status=Paid, chưa trừ Refund_Request.PAID.
    SELECT CONVERT(CHAR(7),p.Payment_Date,126) AS Thang,COUNT(*) AS GiaoDichPaid,SUM(p.Amount) AS TongThuTheoDashboard
    FROM @ThanhToanMoi t JOIN dbo.Payment p ON p.Payment_ID=t.Payment_ID WHERE p.Status=N'Paid'
    GROUP BY CONVERT(CHAR(7),p.Payment_Date,126) ORDER BY Thang;
    SELECT SUM(CASE WHEN r.Status='PAID' THEN r.Approved_Amount ELSE 0 END) AS DaChiHoan,
           SUM(CASE WHEN r.Status='APPROVED' THEN r.Approved_Amount ELSE 0 END) AS ChoChiHoan
    FROM @HoanMoi h JOIN dbo.Refund_Request r ON r.Refund_ID=h.Refund_ID;
    SELECT c.Class_ID,c.Name,s.Session_ID,s.[Date],s.Start_Time,
           N'coach06: điểm danh member09 Có mặt, sau đó tạo đánh giá; member09 xem lại kết quả.' AS HuongDan
    FROM @LopMoi l JOIN dbo.[Class] c ON c.Class_ID=l.Class_ID
    CROSS APPLY (SELECT TOP (1) cs.Session_ID,cs.[Date],cs.Start_Time FROM dbo.Class_Session cs
                 WHERE cs.Class_ID=c.Class_ID AND cs.[Date]<@NgayBaoVe ORDER BY cs.[Date] DESC) s
    WHERE l.Ten=N'Yoga cân bằng';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
