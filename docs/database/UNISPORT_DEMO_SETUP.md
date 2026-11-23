# Cài dữ liệu mẫu UNISPORT để kiểm thử

Hai script nhận từ thư mục `Downloads\SWP391 marterial` đã được đưa vào thư mục này:

- `unisport_demo_dataset.sql`: thêm dữ liệu demo, không xóa dữ liệu đang có.
- `unisport_reset_data.sql`: xóa các dữ liệu/tài khoản ngoài Center Manager Active để nạp lại demo. Chỉ dùng khi thực sự muốn làm sạch DB.

Cả hai file mặc định `@ThucHien = 0` để chỉ xem trước. Đọc kết quả, sao lưu DB, rồi đổi biến thành `1` trong script cần chạy để áp dụng. Không chạy reset nếu muốn giữ lịch sử, tài khoản, giao dịch hoặc dữ liệu người dùng hiện tại. Dataset chỉ chạy một lần trên DB sạch tương thích; nếu gặp tên/email trùng, không bỏ qua kiểm tra trong script.

## Yêu cầu

- SQL Server đang chạy và có database `swp391_demo_db`.
- Backend kết nối `localhost:1433`, user `sa`, password mặc định trong `application.properties` là `123456` (có thể ghi đè bằng `BE-SWP/.env`).
- Schema cần bao gồm các bảng và cột mà dataset kiểm tra. Tạo schema bằng `swp391_db.sql`, sau đó áp dụng các migration trong `migrations` theo thứ tự tên trước khi seed. Script sẽ báo lỗi nếu schema còn thiếu hoặc chưa cập nhật.
- Dừng backend và các tác vụ ghi DB trong lúc reset/seed.

## Nạp dữ liệu để test

1. Mở SQL Server và sao lưu `swp391_demo_db`.
2. Nếu muốn nạp trên DB hiện có, chạy `unisport_demo_dataset.sql` ở chế độ xem trước trước. Nếu tài khoản hoặc dữ liệu mẫu bị trùng, hãy kiểm tra. Muốn nạp lại từ đầu, chạy reset ở chế độ xem trước, xác nhận số bản ghi và tài khoản được giữ, rồi mới áp dụng reset. Reset giữ Role và tài khoản Center Manager có trạng thái Active, nhưng xóa dữ liệu người dùng khác và lịch sử/giao dịch.
3. Trong file muốn áp dụng, đổi `DECLARE @ThucHien BIT = 0` thành `1` và chạy toàn bộ file trong đúng database `swp391_demo_db`. Reset và dataset đều xác thực tên DB; dataset phải chạy sau reset (nếu có).
4. Khởi động backend và frontend để kiểm tra. Tài khoản demo dùng mật khẩu chung `Test2026@`; tài khoản Center Manager cũ vẫn được giữ bởi reset.

Không dùng các dữ liệu/email giả trong môi trường production. Lệnh kết nối SQL Server của ứng dụng có thể được đổi bằng `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME` và `SPRING_DATASOURCE_PASSWORD` trong `.env`.
