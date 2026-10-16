import 'dart:async';
import 'dart:math';

import '../models/crypto_price.dart';

/// Service giả lập dữ liệu giá crypto - tầng Business Logic.
///
/// Minh họa 2 cơ chế bất đồng bộ của Dart:
/// - **Future**: [fetchInitialPrices] - lấy giá ban đầu (1 lần, có độ trễ).
/// - **Stream**: [priceStream] - phát giá liên tục theo thời gian thực.
///
/// Vòng đời: tạo service trong `initState()` của màn hình và BẮT BUỘC gọi
/// [dispose] trong `dispose()` để hủy Timer + đóng StreamController.
class CryptoMockService {
  /// Các tham số tùy chỉnh được truyền qua constructor để dễ kiểm thử.
  CryptoMockService({
    Random? random,
    this.tickInterval = const Duration(seconds: 1),
    this.initialLoadDelay = const Duration(milliseconds: 1000),
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
  final Duration tickInterval;
  final Duration initialLoadDelay;

  /// Xác suất (0.0 - 1.0) một sự kiện giá là "nhiễu" (biến động > 20%)
  /// để demo PriceTransformer lọc và đẩy lỗi.
  final double anomalyRate;

  late final StreamController<CryptoPrice> _controller;
  Timer? _timer;
  final Map<String, double> _currentPrices = Map.of(basePrices);
  bool _isDisposed = false;

  // ---------------------------------------------------------------------------
  // 1. FUTURE (Tải dữ liệu khởi tạo song song với Future.wait)
  // ---------------------------------------------------------------------------

  /// Lấy giá ban đầu của tất cả các coin bằng `Future.wait` (chạy song song).
  Future<List<CryptoPrice>> fetchInitialPrices() async {
    return Future.wait(
      _currentPrices.entries.map((entry) async {
        await Future<void>.delayed(initialLoadDelay);
        return CryptoPrice(
          symbol: entry.key,
          price: entry.value,
          changePercent: 0.0,
          timestamp: DateTime.now(),
        );
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. STREAM (Luồng dữ liệu thời gian thực qua Broadcast StreamController)
  // ---------------------------------------------------------------------------

  /// Luồng giá thời gian thực (broadcast). Mỗi tick phát 1 sự kiện cho mỗi coin.
  Stream<CryptoPrice> get priceStream => _controller.stream;

  /// Timer có đang chạy không (true khi có ít nhất 1 listener).
  bool get isRunning => _timer?.isActive ?? false;

  /// Service đã bị dispose chưa.
  bool get isDisposed => _isDisposed;

  void _startTicking() {
    if (_isDisposed || isRunning) return;
    _timer = Timer.periodic(tickInterval, (_) => _emitTick());
  }

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

      // Bình thường dao động [-2%, +2%]; Nhiễu dao động ±(25% -> 40%)
      final changePercent = isAnomaly
          ? (_random.nextBool() ? 1 : -1) * (25 + _random.nextDouble() * 15)
          : (_random.nextDouble() * 2 - 1) * normalMaxChange;
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

  // ---------------------------------------------------------------------------
  // 3. DISPOSE (Giải phóng tài nguyên an toàn)
  // ---------------------------------------------------------------------------

  /// Giải phóng tài nguyên: hủy Timer và đóng StreamController.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _stopTicking();
    _controller.close();
  }
}

