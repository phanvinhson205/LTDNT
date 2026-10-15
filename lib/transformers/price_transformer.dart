import 'dart:async';

import '../models/crypto_price.dart';

/// Lỗi nhẹ (non-fatal) khi phát hiện biến động giá bất thường.
///
/// Được đẩy qua `sink.addError` để luồng KHÔNG bị đóng, các sự kiện hợp lệ
/// tiếp theo vẫn được phát bình thường.
class PriceAnomalyException implements Exception {
  final String symbol;
  final double changePercent;

  const PriceAnomalyException(this.symbol, this.changePercent);

  @override
  String toString() =>
      'PriceAnomalyException: $symbol biến động bất thường '
      '(${changePercent.toStringAsFixed(2)}%) - đã bị lọc';
}

/// Cung cấp [StreamTransformer] để làm sạch và chuẩn hóa dữ liệu giá.
///
/// Cách dùng:
/// ```dart
/// final cleanStream = rawStream.transform(PriceTransformer.sanitize());
/// ```
class PriceTransformer {
  PriceTransformer._(); // Không cho khởi tạo - chỉ dùng phương thức static.

  /// Ngưỡng biến động tối đa (%) được coi là hợp lệ.
  static const double maxChangePercent = 20.0;

  /// Tạo transformer lọc nhiễu + làm tròn 2 chữ số thập phân.
  static StreamTransformer<CryptoPrice, CryptoPrice> sanitize({
    double threshold = maxChangePercent,
  }) {
    return StreamTransformer<CryptoPrice, CryptoPrice>.fromHandlers(
      // Gọi cho MỖI sự kiện dữ liệu từ luồng nguồn.
      handleData: (CryptoPrice data, EventSink<CryptoPrice> sink) {
        // 1. Sanitization: biến động bất thường -> đẩy lỗi, không phát data.
        if (data.changePercent.abs() > threshold) {
          sink.addError(
            PriceAnomalyException(data.symbol, data.changePercent),
            StackTrace.current,
          );
          return;
        }

        // 2. Dữ liệu hợp lệ -> làm tròn bằng copyWith (giữ tính bất biến).
        sink.add(
          data.copyWith(
            price: _round2(data.price),
            changePercent: _round2(data.changePercent),
          ),
        );
      },
      // Chuyển tiếp lỗi từ luồng nguồn xuống dưới (hành vi mặc định, viết
      // tường minh để minh họa).
      handleError: (Object error, StackTrace stackTrace, EventSink<CryptoPrice> sink) {
        sink.addError(error, stackTrace);
      },
      // Khi luồng nguồn đóng -> đóng luồng đích.
      handleDone: (EventSink<CryptoPrice> sink) {
        sink.close();
      },
    );
  }

  /// Làm tròn đến 2 chữ số thập phân.
  static double _round2(double value) => (value * 100).roundToDouble() / 100;
}

