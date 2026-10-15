# Nguyên tắc dự án Crypto Stream Tracker
- Ngôn ngữ: Dart / Flutter.
- Kiến trúc: Phân tách rõ ràng giữa Business Logic (Stream, Service) và UI (StreamBuilder).
- Yêu cầu xử lý Stream: 
  * Luôn kiểm tra trạng thái Snapshot (hasData, hasError, connectionState).
  * Bắt buộc có cơ chế dispose() để đóng StreamController / StreamSubscription, tránh memory leak.
- Khi chỉnh sửa mã nguồn: Giải thích rõ lý do trước khi đưa ra mã nguồn thay thế.
# SAFETY & WORKSPACE BOUNDARIES
1. Phạm vi thao tác (Scope):
   - CHỈ được tạo hoặc sửa đổi các tệp nằm trong thư mục `lib/` và `test/`.
   - TUYỆT ĐỐI KHÔNG tự ý xóa, đổi tên hoặc sửa các tệp/thư mục hệ thống sau trừ khi được yêu cầu rõ ràng:
     * `android/`, `ios/`, `windows/`, `web/`
     * `pubspec.yaml`, `pubspec.lock`
     * Thư mục `.git/` và lịch sử commit.
2. Lệnh Terminal (CLI Safety):
   - CẤM chạy các lệnh xóa mang tính hủy diệt như: `rm -rf`, `rmdir /s /q`, `del /f /s`, `format`.
   - CẤM tự ý chạy các lệnh Git nguy hiểm: `git reset --hard`, `git clean -fd`, `git push --force`.
   - Mọi câu lệnh terminal đều phải giải thích mục đích trước khi yêu cầu cấp quyền chạy.
3. Nguyên tắc sửa mã nguồn:
   - Không xóa comment giải thích hoặc code hiện có nếu không liên quan đến tác vụ được giao.
   - Khi chỉnh sửa, ưu tiên hiển thị Diff rõ ràng thay vì ghi đè mù toàn bộ tệp lớn.