# Crypto Stream Tracker

> **Báo cáo Chuyên đề: Dart & Flutter**  
> **Trường Đại học Bách Khoa – Đại học Đà Nẵng | Khoa Điện tử và Trí tuệ nhân tạo**  
> **Giảng viên hướng dẫn:** TS. Nguyễn Duy Nhật Viễn  
> **Chủ đề 02:** Lập trình Bất đồng bộ với Future & Stream: Xây dựng Module Reactive thời gian thực

---

## 1. Hướng dẫn Cài đặt & Chạy ứng dụng

### Yêu cầu hệ thống
- **Flutter SDK**: `>= 3.0.0` (Dart SDK `^3.12.2`)
- **Thiết bị chạy**: Máy ảo Android/iOS, Windows Desktop hoặc trình duyệt Chrome.

### Các bước cài đặt
1. **Clone mã nguồn từ GitHub:**
   ```bash
   git clone https://github.com/phanvinhson205/LTDNT.git
   cd LTDNT
   ```

2. **Tải các gói thư viện phụ thuộc:**
   ```bash
   flutter pub get
   ```

3. **Chạy ứng dụng:**
   ```bash
   flutter run
   ```

4. **Chạy kiểm thử tự động (Unit & Widget Tests):**
   ```bash
   flutter test
   ```

---

## 2. Cấu hình Biến môi trường (`.env`) & `google-services.json`

- **Chế độ mặc định:** Dự án sử dụng `CryptoMockService` để giả lập biến động giá thời gian thực ngay trong ứng dụng nên có thể chạy trực tiếp sau khi `flutter pub get` mà không bắt buộc cấu hình API bên ngoài.
- **Cấu hình tệp `.env` (khi kết nối WebSocket/API thực tế):**  
  Tạo tệp `.env` tại thư mục gốc dự án:
  ```env
  CRYPTO_WS_URL=wss://stream.binance.com:9443/ws
  TICK_INTERVAL_MS=1000
  ANOMALY_THRESHOLD_PERCENT=20.0
  ```
- **Cấu hình `google-services.json` (khi tích hợp Firebase):**  
  Đặt tệp cấu hình vào đường dẫn `android/app/google-services.json` (Android) hoặc `ios/Runner/GoogleService-Info.plist` (iOS).

---

## 3. Phân chia Commit theo Thành viên

| Thành viên | GitHub | Nhiệm vụ phân chia commit | Các tệp phụ trách |
|:---|:---|:---|:---|
| **Phan Vĩnh Sơn** | [@phanvinhson205](https://github.com/phanvinhson205) | - Cấu hình ứng dụng và Theme (`main.dart`)<br>- Xây dựng model dữ liệu `CryptoPrice`<br>- Thiết kế thẻ hiển thị giá coin `PriceTile`<br>- Xây dựng giao diện `TrackerScreen` (tải giá khởi tạo với `FutureBuilder`)<br>- Viết kiểm thử giao diện `widget_test.dart`<br>- Quản lý tài liệu `README.md` | `lib/main.dart`<br>`lib/models/crypto_price.dart`<br>`lib/widgets/price_tile.dart`<br>`lib/views/tracker_screen.dart`<br>`test/widget_test.dart`<br>`README.md` |
| **Thành viên 2** | *[@thanhvien2]* | - Hiện thực service giả lập giá `CryptoMockService` (`Future.wait`, `StreamController.broadcast`, `dispose`)<br>- Xây dựng bộ lọc biến động giá `PriceTransformer` (lọc nhiễu >20%, làm tròn giá)<br>- Viết bộ kiểm thử Unit Test cho Model, Service và Transformer | `lib/services/crypto_mock_service.dart`<br>`lib/transformers/price_transformer.dart`<br>`test/models/`<br>`test/services/`<br>`test/transformers/` |
