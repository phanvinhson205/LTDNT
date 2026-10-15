import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_stream_tracker/services/crypto_mock_service.dart';
import 'package:crypto_stream_tracker/views/home_screen.dart';
import 'package:crypto_stream_tracker/views/tracker_screen.dart';
import 'package:crypto_stream_tracker/widgets/price_tile.dart';

void main() {
  group('HomeScreen Widget Tests (FutureBuilder & Navigation)', () {
    testWidgets('hiển thị trạng thái loading trước khi Future hoàn thành',
        (WidgetTester tester) async {
      // Service với độ trễ giả lập 500ms
      final service = CryptoMockService(
        initialLoadDelay: const Duration(milliseconds: 500),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(service: service),
        ),
      );

      // Khi vừa khởi chạy: FutureBuilder ở trạng thái ConnectionState.waiting
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Đang tải dữ liệu khởi tạo...'), findsOneWidget);

      // Đợi hoàn tất Future để đóng luồng sạch sẽ
      await tester.pumpAndSettle();
      service.dispose();
    });

    testWidgets('hiển thị danh sách coin và điều hướng sang TrackerScreen thành công',
        (WidgetTester tester) async {
      // Service tải nhanh (10ms) và không có lỗi
      final service = CryptoMockService(
        initialLoadDelay: const Duration(milliseconds: 10),
        initialLoadFailureRate: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(service: service),
        ),
      );

      // Chờ Future.wait hoàn thành
      await tester.pumpAndSettle();

      // Kiểm tra các thẻ PriceTile được hiển thị trên UI chính xác theo symbol
      expect(
        find.byWidgetPredicate(
            (w) => w is PriceTile && w.price.symbol == 'BTC'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
            (w) => w is PriceTile && w.price.symbol == 'ETH'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
            (w) => w is PriceTile && w.price.symbol == 'SOL'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
            (w) => w is PriceTile && w.price.symbol == 'BNB'),
        findsOneWidget,
      );

      // Kiểm tra nút điều hướng
      final navigateButton =
          find.text('Mở Module Realtime Tracker (Stream)');
      expect(navigateButton, findsOneWidget);

      // Nhấn nút để chuyển màn hình sang TrackerScreen
      await tester.tap(navigateButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Xác minh đã điều hướng sang TrackerScreen
      expect(find.byType(TrackerScreen), findsOneWidget);
      expect(find.text('Realtime Stream Tracker'), findsOneWidget);

      service.dispose();
    });

    testWidgets('hiển thị giao diện báo lỗi và nút Thử lại khi Future thất bại',
        (WidgetTester tester) async {
      // Cấu hình service luôn ném lỗi
      final service = CryptoMockService(
        initialLoadDelay: const Duration(milliseconds: 10),
        initialLoadFailureRate: 1.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(service: service),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra UI bắt được lỗi qua snapshot.hasError
      expect(find.text('Không thể tải dữ liệu thị trường'), findsOneWidget);
      expect(find.text('Thử lại (Retry Future)'), findsOneWidget);

      service.dispose();
    });
  });
}
