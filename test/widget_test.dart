import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_stream_tracker/services/crypto_mock_service.dart';
import 'package:crypto_stream_tracker/views/tracker_screen.dart';

void main() {
  group('TrackerScreen Widget Tests (All-in-One Dashboard)', () {
    testWidgets('hiển thị đầy đủ cả Module Future và Module Stream',
        (WidgetTester tester) async {
      final service = CryptoMockService(
        random: Random(42),
        initialLoadDelay: const Duration(milliseconds: 10),
        tickInterval: const Duration(milliseconds: 100),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TrackerScreen(service: service),
        ),
      );

      // Chờ Future.wait và 1-2 tick của Stream
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Kiểm tra tiêu đề các Module
      expect(
        find.text('1. Module Future: Giá khởi tạo (Future.wait)'),
        findsOneWidget,
      );
      expect(
        find.text('2. Module Stream Reactive: Biến động giá Realtime'),
        findsOneWidget,
      );

      // Kiểm tra thông báo hoàn thành của Future
      expect(
        find.text('✓ Future hoàn thành: Đã nạp thành công 4 đồng coin ban đầu.'),
        findsOneWidget,
      );

      // Đóng service và thoát an toàn
      service.dispose();
      await tester.pump();
    });

    testWidgets('nhấn nút Hủy luồng an toàn (Dispose) chuyển trạng thái Đã đóng',
        (WidgetTester tester) async {
      final service = CryptoMockService(
        initialLoadDelay: const Duration(milliseconds: 10),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TrackerScreen(service: service),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));

      // Nhấn nút Hủy luồng trên AppBar
      final stopButton = find.byIcon(Icons.stop_circle_outlined);
      expect(stopButton, findsOneWidget);
      await tester.tap(stopButton);
      await tester.pump();

      // Kiểm tra trạng thái đã đóng an toàn
      expect(find.textContaining('Đã đóng (Closed)'), findsOneWidget);

      service.dispose();
      await tester.pump();
    });
  });
}
