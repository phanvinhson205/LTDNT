import 'dart:async';

import 'package:flutter/material.dart';

import '../models/crypto_price.dart';
import '../services/crypto_mock_service.dart';
import '../transformers/price_transformer.dart';
import '../widgets/price_tile.dart';

/// Màn hình All-in-One thể hiện trọn vẹn Chủ đề 02:
/// "Lập trình Bất đồng bộ với Future & Stream: Xây dựng Module Reactive thời gian thực"
///
/// Bao gồm đầy đủ:
/// 1. Future & async/await qua FutureBuilder (tải giá mở cửa ban đầu)
/// 2. Stream & StreamController.broadcast qua StreamBuilder (biến động realtime)
/// 3. Toán tử biến đổi StreamTransformer (lọc nhiễu >20% qua sink.addError)
/// 4. StreamSubscription (quản lý Pause/Resume)
/// 5. Hủy luồng an toàn (Cancellation / Dispose) chống rò rỉ bộ nhớ
class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key, this.service});

  final CryptoMockService? service;

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  late final CryptoMockService _service;
  late final Stream<CryptoPrice> _cleanPriceStream;
  late Future<List<CryptoPrice>> _initialPricesFuture;

  StreamSubscription<CryptoPrice>? _priceSubscription;
  final Map<String, CryptoPrice> _latestPrices = {};

  int _validCount = 0;
  int _anomalyCount = 0;
  String? _lastAnomaly;
  bool _isPaused = false;
  bool _isStreamClosed = false;

  @override
  void initState() {
    super.initState();

    // 1. Khởi tạo Service Business Logic
    _service = widget.service ??
        CryptoMockService(
          initialLoadDelay: const Duration(milliseconds: 1000),
          tickInterval: const Duration(seconds: 1),
          anomalyRate: 0.15, // 15% xác suất tạo biến động >20% để demo transformer
        );

    // 2. FUTURE: Gọi tải dữ liệu khởi tạo 1 lần qua FutureBuilder
    _initialPricesFuture = _service.fetchInitialPrices();

    // 3. STREAM & TRANSFORMER: Lọc nhiễu qua PriceTransformer trước khi tới UI
    _cleanPriceStream = _service.priceStream.transform(
      PriceTransformer.sanitize(),
    );

    // 4. STREAM SUBSCRIPTION: Lắng nghe ngầm để Pause/Resume & Thống kê
    _subscribe();
  }

  void _subscribe() {
    _priceSubscription = _cleanPriceStream.listen(
      (CryptoPrice price) {
        setState(() {
          _latestPrices[price.symbol] = price;
          _validCount++;
        });
      },
      onError: (Object error) {
        setState(() {
          _anomalyCount++;
          _lastAnomaly = error.toString();
        });
      },
      onDone: () {
        setState(() => _isStreamClosed = true);
      },
      cancelOnError: false, // Lỗi không làm đứt luồng
    );
  }

  /// Quản lý tạm dừng hoặc tiếp tục nhận dữ liệu từ StreamSubscription
  void _togglePauseResume() {
    if (_priceSubscription == null || _isStreamClosed) return;
    setState(() {
      if (_isPaused) {
        _priceSubscription!.resume();
        _isPaused = false;
      } else {
        _priceSubscription!.pause();
        _isPaused = true;
      }
    });
  }

  /// Hủy luồng an toàn (Cancellation): Đóng StreamController & Hủy Timer
  void _stopStream() {
    setState(() {
      _service.dispose();
      _isStreamClosed = true;
    });
  }

  /// BẮT BUỘC: Hủy Subscription và Service khi thoát màn hình để tránh memory leak
  @override
  void dispose() {
    _priceSubscription?.cancel();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crypto Stream Tracker (Chủ đề 02)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: _isPaused ? 'Tiếp tục luồng' : 'Tạm dừng luồng',
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            onPressed: _isStreamClosed ? null : _togglePauseResume,
          ),
          IconButton(
            tooltip: 'Hủy luồng an toàn (Dispose)',
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: _isStreamClosed ? null : _stopStream,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // =================================================================
            // PHẦN 1: MODULE FUTURE (FutureBuilder)
            // =================================================================
            _buildSectionHeader('1. Module Future: Giá khởi tạo (Future.wait)'),
            FutureBuilder<List<CryptoPrice>>(
              future: _initialPricesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 12),
                          Text('Future.wait() đang nạp giá mở cửa...', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text('Lỗi Future: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  );
                }
                if (snapshot.hasData) {
                  for (final p in snapshot.data!) {
                    _latestPrices.putIfAbsent(p.symbol, () => p);
                  }
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      '✓ Future hoàn thành: Đã nạp thành công ${snapshot.data!.length} đồng coin ban đầu.',
                      style: TextStyle(color: Colors.blue.shade900, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            const Divider(thickness: 1, height: 24),

            // =================================================================
            // PHẦN 2: MODULE STREAM (StreamBuilder & Transformer & Subscription)
            // =================================================================
            _buildSectionHeader('2. Module Stream Reactive: Biến động giá Realtime'),

            // Bảng điều khiển & thống kê gói tin / lỗi lọc
            _buildStreamStatsCard(),

            // StreamBuilder lắng nghe sự kiện tức thời & kiểm tra đầy đủ trạng thái Snapshot
            StreamBuilder<CryptoPrice>(
              stream: _cleanPriceStream,
              builder: (context, snapshot) {
                Widget statusBanner = const SizedBox.shrink();

                if (snapshot.connectionState == ConnectionState.waiting) {
                  statusBanner = const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Đang kết nối luồng dữ liệu thời gian thực...'),
                  );
                } else if (snapshot.connectionState == ConnectionState.done) {
                  statusBanner = Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Luồng đã đóng an toàn (ConnectionState.done).'),
                  );
                } else if (snapshot.hasError) {
                  // Lỗi lọc dị thường (>20%) từ PriceTransformer được lưu và hiển thị
                  // ổn định tại bảng thống kê (_lastAnomaly) thay vì chớp tắt trên UI.
                } else if (snapshot.hasData && !_isPaused) {
                  _latestPrices[snapshot.data!.symbol] = snapshot.data!;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: statusBanner,
                    ),
                    // Bảng danh sách giá Realtime được render trực tiếp trong StreamBuilder
                    ..._latestPrices.values.map((price) => PriceTile(price: price)),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
      ),
    );
  }

  Widget _buildStreamStatsCard() {
    final statusText = _isStreamClosed
        ? 'Đã đóng (Closed)'
        : (_isPaused ? 'Tạm dừng (Paused)' : 'Đang phát trực tiếp');
    final statusColor = _isStreamClosed ? Colors.grey : (_isPaused ? Colors.amber.shade800 : Colors.green.shade700);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Trạng thái luồng: $statusText', style: TextStyle(fontWeight: FontWeight.bold, color: statusColor)),
              Text('Hợp lệ: $_validCount | Nhiễu: $_anomalyCount', style: const TextStyle(fontSize: 12)),
            ],
          ),
          if (_lastAnomaly != null) ...[
            const SizedBox(height: 6),
            Text(
              'Nhiễu gần nhất: $_lastAnomaly',
              style: TextStyle(fontSize: 11, color: Colors.orange.shade900, fontStyle: FontStyle.italic),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
