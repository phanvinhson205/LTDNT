/// Model bất biến (immutable) đại diện cho một lần cập nhật giá tiền ảo.
///
/// Mỗi sự kiện phát ra từ Stream giá sẽ là một instance mới của [CryptoPrice],
/// thay vì sửa trực tiếp object cũ -> giúp StreamBuilder/UI nhận diện thay đổi
/// rõ ràng và tránh side-effect giữa các listener.
class CryptoPrice {
  /// Mã tiền ảo, ví dụ: BTC, ETH.
  final String symbol;

  /// Giá hiện tại (USD).
  final double price;

  /// Tỷ lệ thay đổi giá so với lần cập nhật trước (đơn vị: %).
  final double changePercent;

  /// Thời điểm cập nhật giá.
  final DateTime timestamp;

  /// Constructor `const` với named parameters bắt buộc.
  const CryptoPrice({
    required this.symbol,
    required this.price,
    required this.changePercent,
    required this.timestamp,
  });

  /// Tạo bản sao mới, chỉ thay đổi các trường được truyền vào.
  /// Các trường không truyền (null) sẽ giữ nguyên giá trị cũ.
  CryptoPrice copyWith({
    String? symbol,
    double? price,
    double? changePercent,
    DateTime? timestamp,
  }) {
    return CryptoPrice(
      symbol: symbol ?? this.symbol,
      price: price ?? this.price,
      changePercent: changePercent ?? this.changePercent,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Log ngắn gọn khi debug Stream.
  /// Ví dụ: `[13:21:56] BTC: 65000.00 (+1.25%)`
  @override
  String toString() {
    final time = '${_twoDigits(timestamp.hour)}:'
        '${_twoDigits(timestamp.minute)}:'
        '${_twoDigits(timestamp.second)}';
    final sign = changePercent >= 0 ? '+' : '';
    return '[$time] $symbol: ${price.toStringAsFixed(2)} '
        '($sign${changePercent.toStringAsFixed(2)}%)';
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');
}

