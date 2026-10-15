import 'dart:async';

import 'package:flutter/material.dart';

import '../models/crypto_price.dart';
import '../services/crypto_mock_service.dart';
import '../transformers/price_transformer.dart';
import '../widgets/price_tile.dart';

/// Màn hình theo dõi biến động giá Crypto thời gian thực.
///
/// Thể hiện đầy đủ các kỹ thuật cốt lõi về Stream trong Flutter:
/// 1. **StreamTransformer**: Làm sạch và lọc nhiễu trước khi đưa tới UI.
/// 2. **StreamBuilder**: Tự động re-render theo trạng thái Snapshot
///    (ConnectionState, hasError, hasData).
/// 3. **StreamSubscription**: Lắng nghe ngầm để Pause/Resume, thống kê gói tin
///    và bắt các ngoại lệ biến động bất thường.
/// 4. **dispose()**: Giải phóng Subscription và đóng Service chống Memory Leak.
class TrackerScreen extends StatefulWidget {
  const TrackerScreen({
    super.key,
    this.service,
    this.initialPrices,
  });

  /// Service cung cấp dữ liệu Stream (nếu null màn hình sẽ tự khởi tạo).
  final CryptoMockService? service;

  /// Danh sách giá ban đầu nhận từ Future của HomeScreen (nếu có).
  final List<CryptoPrice>? initialPrices;

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  late final CryptoMockService _service;
  late final Stream<CryptoPrice> _cleanPriceStream;

  // Quản lý lắng nghe Stream cấp thấp để Pause/Resume & Thống kê
  StreamSubscription<CryptoPrice>? _priceSubscription;

  // Bảng lưu giá mới nhất của từng đồng coin để hiển thị danh sách
  final Map<String, CryptoPrice> _latestPrices = {};

  // Các biến thống kê phục vụ báo cáo / demo
  int _validEventCount = 0;
  int _anomalyCount = 0;
  String? _lastAnomalyInfo;
  bool _isPaused = false;
  bool _isDisposedInternally = false;

  @override
  void initState() {
    super.initState();

    // 1. Khởi tạo service (nhận từ ngoài hoặc tạo mới)
    _service = widget.service ??
        CryptoMockService(
          tickInterval: const Duration(seconds: 1),
          anomalyRate: 0.15, // Đặt 15% tỷ lệ nhiễu để dễ quan sát transformer
        );

    // Nạp dữ liệu ban đầu nếu HomeScreen truyền sang
    if (widget.initialPrices != null) {
      for (final p in widget.initialPrices!) {
        _latestPrices[p.symbol] = p;
      }
    }

    // 2. Ứng dụng StreamTransformer để làm sạch dữ liệu
    _cleanPriceStream = _service.priceStream.transform(
      PriceTransformer.sanitize(),
    );

    // 3. Đăng ký StreamSubscription để quản lý Pause/Resume và đếm lỗi
    _subscribeToStream();
  }

  void _subscribeToStream() {
    _priceSubscription = _cleanPriceStream.listen(
      (CryptoPrice price) {
        setState(() {
          _latestPrices[price.symbol] = price;
          _validEventCount++;
        });
      },
      onError: (Object error) {
        setState(() {
          _anomalyCount++;
          _lastAnomalyInfo = error.toString();
        });
      },
      onDone: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Luồng Stream đã đóng hoàn tất.')),
          );
        }
      },
      cancelOnError: false, // Lỗi không làm ngắt luồng
    );
  }

  /// Tạm dừng hoặc Tiếp tục nhận dữ liệu qua StreamSubscription
  void _togglePauseResume() {
    if (_priceSubscription == null) return;

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

  /// Minh họa việc chủ động đóng luồng dữ liệu từ phía nguồn
  void _stopStream() {
    setState(() {
      _service.dispose();
      _isDisposedInternally = true;
    });
  }

  /// BẮT BUỘC theo quy tắc AGENTS.md:
  /// Hủy subscription và đóng service để ngăn ngừa rò rỉ bộ nhớ hoàn toàn.
  @override
  void dispose() {
    _priceSubscription?.cancel();
    if (!_isDisposedInternally) {
      _service.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Realtime Stream Tracker'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: _isPaused ? 'Tiếp tục luồng' : 'Tạm dừng luồng',
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            onPressed: _isDisposedInternally ? null : _togglePauseResume,
          ),
          IconButton(
            tooltip: 'Đóng Stream hoàn toàn',
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: _isDisposedInternally ? null : _stopStream,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -----------------------------------------------------------------
            // KHU VỰC 1: BẢNG ĐIỀU KHIỂN & THỐNG KÊ STREAM
            // -----------------------------------------------------------------
            _buildControlPanel(),

            // -----------------------------------------------------------------
            // KHU VỰC 2: MINH HỌA XỬ LÝ SNAPSHOT QUA STREAMBUILDER
            // -----------------------------------------------------------------
            _buildStreamBuilderSection(),

            const Divider(thickness: 1.5, height: 28),

            // -----------------------------------------------------------------
            // KHU VỰC 3: BẢNG GIÁ ĐỒNG THỜI CÁC COIN
            // -----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Bảng giá thị trường trực tiếp',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_latestPrices.length} mã theo dõi',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (_latestPrices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: Text('Đang đợi dữ liệu ban đầu...')),
              )
            else
              ..._latestPrices.values.map(
                (price) => PriceTile(price: price),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Bảng trạng thái Subscription và thống kê gói tin
  Widget _buildControlPanel() {
    final statusColor = _isDisposedInternally
        ? Colors.grey
        : (_isPaused ? Colors.amber.shade800 : Colors.green.shade700);

    final statusText = _isDisposedInternally
        ? 'Đã ngắt kết nối'
        : (_isPaused ? 'Đang tạm dừng (Paused)' : 'Đang phát trực tiếp');

    return Card(
      margin: const EdgeInsets.all(12),
      color: Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sensors, color: statusColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Trạng thái Subscription: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey.shade900,
                  ),
                ),
                Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Gói tin hợp lệ',
                    value: '$_validEventCount',
                    color: Colors.green.shade700,
                    icon: Icons.check_circle_outline,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Nhiễu đã lọc (>20%)',
                    value: '$_anomalyCount',
                    color: Colors.orange.shade800,
                    icon: Icons.filter_alt_outlined,
                  ),
                ),
              ],
            ),
            if (_lastAnomalyInfo != null) ...[
              const SizedBox(height: 8),
              Text(
                'Lỗi lọc gần nhất: $_lastAnomalyInfo',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.red.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Khu vực minh họa rõ ràng các nhánh trạng thái của StreamBuilder
  Widget _buildStreamBuilderSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Live Event Feed (StreamBuilder):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          StreamBuilder<CryptoPrice>(
            stream: _cleanPriceStream,
            builder: (BuildContext context, AsyncSnapshot<CryptoPrice> snapshot) {
              // 1. Kiểm tra trạng thái đang chờ sự kiện đầu tiên
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Đang lắng nghe Stream... (ConnectionState.waiting)',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // 2. Kiểm tra nếu có lỗi phát ra qua sink.addError (Lọc nhiễu)
              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Phát hiện lỗi trên Stream (snapshot.hasError)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade900,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${snapshot.error}',
                              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              // 3. Kiểm tra khi luồng đã đóng hoàn tất
              if (snapshot.connectionState == ConnectionState.done) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.grey),
                      SizedBox(width: 10),
                      Text(
                        'Luồng đã kết thúc (ConnectionState.done)',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                );
              }

              // 4. Có dữ liệu hợp lệ (snapshot.hasData)
              if (snapshot.hasData) {
                final latest = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Vừa nhận gói tin: ${latest.symbol} lúc '
                        '${latest.timestamp.hour.toString().padLeft(2, '0')}:'
                        '${latest.timestamp.minute.toString().padLeft(2, '0')}:'
                        '${latest.timestamp.second.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                      ),
                    ),
                    const SizedBox(height: 4),
                    PriceTile(price: latest),
                  ],
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

