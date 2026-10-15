import 'package:flutter/material.dart';

import '../models/crypto_price.dart';
import '../services/crypto_mock_service.dart';
import '../widgets/price_tile.dart';
import 'tracker_screen.dart';

/// Màn hình chính minh họa cơ chế bất đồng bộ Future trong Flutter.
///
/// Thể hiện đầy đủ các kỹ thuật:
/// 1. **Future & async/await**: Gọi service tải giá ban đầu qua [fetchInitialPrices].
/// 2. **FutureBuilder**: Quản lý vòng đời bất đồng bộ một lần (one-shot asynchronous)
///    với đầy đủ 3 trạng thái: Loading (waiting), Error (hasError), Data (hasData).
/// 3. **Cơ chế Retry**: Khởi chạy lại Future khi xảy ra ngoại lệ mạng giả lập.
/// 4. **Điều hướng**: Chuyển dữ liệu khởi tạo sang màn hình Realtime Stream Tracker.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.service,
  });

  /// Service bất đồng bộ (tùy chọn truyền vào để phục vụ test).
  final CryptoMockService? service;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late CryptoMockService _service;
  late Future<List<CryptoPrice>> _initialPricesFuture;

  // Cờ giả lập lỗi mạng để giảng viên nghiệm thu nhánh snapshot.hasError
  bool _simulateNetworkError = false;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  void _initService() {
    _service = widget.service ??
        CryptoMockService(
          initialLoadDelay: const Duration(milliseconds: 1200),
          initialLoadFailureRate: _simulateNetworkError ? 1.0 : 0.0,
        );

    // Bắt đầu gọi Future một lần ngay trong initState
    // (Tránh gọi trực tiếp trong build() gây re-trigger API mỗi lần widget rebuild)
    _initialPricesFuture = _service.fetchInitialPrices();
  }

  /// Khởi chạy lại Future để tải lại dữ liệu (Pattern xử lý Retry)
  void _retryLoading() {
    setState(() {
      _initService();
    });
  }

  @override
  void dispose() {
    // Nếu service do màn hình này tự tạo thì cần dispose khi màn hình thoát
    if (widget.service == null) {
      _service.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crypto Market (Future Demo)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: 'Tải lại danh sách (Future)',
            icon: const Icon(Icons.refresh),
            onPressed: _retryLoading,
          ),
        ],
      ),
      body: Column(
        children: [
          // Khu vực chuyển đổi chế độ giả lập lỗi để kiểm thử UI
          _buildSimulationBanner(),

          // Khu vực chính: Sử dụng FutureBuilder để xử lý 3 trạng thái Snapshot
          Expanded(
            child: FutureBuilder<List<CryptoPrice>>(
              future: _initialPricesFuture,
              builder: (BuildContext context,
                  AsyncSnapshot<List<CryptoPrice>> snapshot) {
                // 1. TRẠNG THÁI WAITING: Đang chờ Future hoàn thành
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }

                // 2. TRẠNG THÁI ERROR: Bắt ngoại lệ nếu Future ném lỗi
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error);
                }

                // 3. TRẠNG THÁI SUCCESS: Future trả về dữ liệu hợp lệ
                if (snapshot.hasData) {
                  return _buildSuccessState(snapshot.data!);
                }

                return const Center(child: Text('Không có dữ liệu'));
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Banner cấu hình giả lập lỗi mạng
  Widget _buildSimulationBanner() {
    return Container(
      color: Colors.blueGrey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.tune, size: 20, color: Colors.blueGrey.shade700),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Giả lập lỗi mạng khi gọi Future:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Switch(
            value: _simulateNetworkError,
            activeTrackColor: Colors.red.shade200,
            activeThumbColor: Colors.red.shade700,
            onChanged: (bool value) {
              setState(() {
                _simulateNetworkError = value;
                _retryLoading();
              });
            },
          ),
        ],
      ),
    );
  }

  /// 1. Giao diện trạng thái đang tải (Loading)
  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text(
              'Đang tải dữ liệu khởi tạo...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Đang chạy: Future.wait() song song cho 4 đồng coin\n'
              'Độ trễ giả lập: 1200ms',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  /// 2. Giao diện trạng thái lỗi (Error handling)
  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade600),
            const SizedBox(height: 16),
            const Text(
              'Không thể tải dữ liệu thị trường',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _retryLoading,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại (Retry Future)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 3. Giao diện hiển thị danh sách coin và nút chuyển sang Stream Tracker
  Widget _buildSuccessState(List<CryptoPrice> prices) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tải thành công ${prices.length} mã coin qua Future.wait()',
                  style: TextStyle(
                    color: Colors.green.shade900,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: prices.length,
            itemBuilder: (context, index) {
              return PriceTile(price: prices[index]);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                // Điều hướng sang TrackerScreen, tái sử dụng service và truyền giá ban đầu
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TrackerScreen(
                      initialPrices: prices,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.bolt, size: 22),
              label: const Text(
                'Mở Module Realtime Tracker (Stream)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
