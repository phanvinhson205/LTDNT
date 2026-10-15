import 'dart:async';
import 'dart:math';

import '../models/crypto_price.dart';

/// Lỗi nghiệp vụ khi service không lấy được dữ liệu (giả lập lỗi mạng).
class CryptoServiceException implements Exception {
  final String message;

  const CryptoServiceException(this.message);

  @override
  String toString() => 'CryptoServiceException: $message';
}

/// Service giả lập dữ liệu giá crypto - tầng Business Logic.
///
/// Minh họa 2 cơ chế bất đồng bộ của Dart:
/// - **Future**: [fetchInitialPrices] - lấy giá ban đầu (1 lần, có độ trễ).
/// - **Stream**: [priceStream] - phát giá liên tục theo thời gian thực.
///
/// Vòng đời: tạo service trong `initState()` của màn hình và BẮT BUỘC gọi
/// [dispose] trong `dispose()` để hủy Timer + đóng StreamController.
class CryptoMockService {
  /// Các tham số tùy chỉnh được truyền qua constructor để dễ kiểm thử
  /// (ví dụ: truyền `Random(42)` để kết quả ổn định, tick nhanh hơn...).
  CryptoMockService({
    Random? random,
    this.tickInterval = const Duration(seconds: 1),
    this.initialLoadDelay = const Duration(milliseconds: 1500),
    this.initialLoadFailureRate = 0.0,
    this.anomalyRate = 0.05,
  }) : _random = random ?? Random() {
    // Broadcast: cho phép NHIỀU listener cùng nghe (StreamBuilder + Subscription
    // đếm lỗi). onListen/onCancel giúp Timer chỉ chạy khi có người nghe.
    _controller = StreamController<CryptoPrice>.broadcast(
      onListen: _startTicking,
      onCancel: _stopTicking,
    );
  }

  /// Giá gốc của các đồng coin được giả lập (USD).
  static const Map<String, double> basePrices = {
    'BTC': 65000.0,
    'ETH': 3200.0,
    'BNB': 580.0,
    'SOL': 150.0,
  };

  /// Biên độ dao động bình thường mỗi tick: ±2%.
  static const double normalMaxChange = 2.0;

  final Random _random;

  /// Chu kỳ phát giá mới.
  final Duration tickInterval;

  /// Độ trễ giả lập khi tải giá ban đầu (Future).
  final Duration initialLoadDelay;

  /// Xác suất (0.0 - 1.0) tải giá ban đầu bị lỗi - để demo xử lý lỗi Future.
  final double initialLoadFailureRate;

  /// Xác suất (0.0 - 1.0) một sự kiện giá là "nhiễu" (biến động > 20%)
  /// - để demo PriceTransformer lọc và đẩy lỗi.
  final double anomalyRate;

  late final StreamController<CryptoPrice> _controller;
  Timer? _timer;
  final Map<String, double> _currentPrices = Map.of(basePrices);
  bool _isDisposed = false;

  // ---------------------------------------------------------------------------
  // FUTURE
  // ---------------------------------------------------------------------------

  /// Lấy giá ban đầu của tất cả các coin.
  ///
  /// Dùng `Future.wait` để "gọi API" cho từng coin SONG SONG: tổng thời gian
  /// ≈ thời gian của 1 lần gọi, thay vì cộng dồn nếu `await` tuần tự.
  ///
  /// Ném [CryptoServiceException] nếu giả lập lỗi mạng.
  Future<List<CryptoPrice>> fetchInitialPrices() async {
    _ensureNotDisposed();

    final prices = await Future.wait(
      _currentPrices.keys.map(_fetchSinglePrice),
    );

    if (_random.nextDouble() < initialLoadFailureRate) {
      throw const CryptoServiceException(
        'Không thể kết nối máy chủ giá. Vui lòng thử lại.',
      );
    }
    return prices;
  }

  /// Giả lập 1 lời gọi API lấy giá của 1 coin.
  Future<CryptoPrice> _fetchSinglePrice(String symbol) async {
    await Future<void>.delayed(initialLoadDelay);
    return CryptoPrice(
      symbol: symbol,
      price: _currentPrices[symbol]!,
      changePercent: 0.0,
      timestamp: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // STREAM
  // ---------------------------------------------------------------------------

  /// Luồng giá thời gian thực (broadcast). Mỗi tick phát 1 sự kiện cho mỗi coin.
  ///
  /// Đây là dữ liệu THÔ (có thể chứa nhiễu) - UI nên dùng kèm
  /// `.transform(PriceTransformer.sanitize())`.
  Stream<CryptoPrice> get priceStream => _controller.stream;

  /// Timer có đang chạy không (true khi có ít nhất 1 listener).
  bool get isRunning => _timer?.isActive ?? false;

  /// Service đã bị dispose chưa.
  bool get isDisposed => _isDisposed;

  /// Gọi khi listener ĐẦU TIÊN đăng ký.
  void _startTicking() {
    if (_isDisposed || isRunning) return;
    _timer = Timer.periodic(tickInterval, (_) => _emitTick());
  }

  /// Gọi khi listener CUỐI CÙNG hủy đăng ký -> dừng Timer, tiết kiệm tài nguyên.
  void _stopTicking() {
    _timer?.cancel();
    _timer = null;
  }

  /// Sinh giá mới cho mọi coin và đẩy vào Stream.
  void _emitTick() {
    if (_controller.isClosed) return;
    final now = DateTime.now();

    for (final symbol in _currentPrices.keys) {
      final oldPrice = _currentPrices[symbol]!;
      final isAnomaly = _random.nextDouble() < anomalyRate;

      final changePercent =
          isAnomaly ? _randomAnomalyChange() : _randomNormalChange();
      final newPrice = oldPrice * (1 + changePercent / 100);

      // Nhiễu KHÔNG được ghi nhận vào giá hiện tại -> giá thật không bị lệch.
      if (!isAnomaly) {
        _currentPrices[symbol] = newPrice;
      }

      _controller.add(
        CryptoPrice(
          symbol: symbol,
          price: newPrice,
          changePercent: changePercent,
          timestamp: now,
        ),
      );
    }
  }

  /// Dao động bình thường trong khoảng [-2%, +2%).
  double _randomNormalChange() =>
      (_random.nextDouble() * 2 - 1) * normalMaxChange;

  /// Dao động bất thường: ±25% đến ±40%.
  double _randomAnomalyChange() {
    final sign = _random.nextBool() ? 1 : -1;
    return sign * (25 + _random.nextDouble() * 15);
  }

  // ---------------------------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------------------------

  /// Giải phóng tài nguyên: hủy Timer và đóng StreamController.
  ///
  /// Sau khi gọi, mọi listener nhận sự kiện `done`. Gọi nhiều lần vẫn an toàn.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _stopTicking();
    _controller.close();
  }

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError('CryptoMockService đã bị dispose, không thể sử dụng.');
    }
  }
}

