import 'dart:math';

import 'package:crypto_stream_tracker/models/crypto_price.dart';
import 'package:crypto_stream_tracker/services/crypto_mock_service.dart';
import 'package:crypto_stream_tracker/transformers/price_transformer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CryptoMockService service;

  /// Tạo service với tham số nhanh + Random cố định để test ổn định.
  CryptoMockService createService({
    double failureRate = 0.0,
    double anomalyRate = 0.0,
    Duration loadDelay = const Duration(milliseconds: 10),
  }) {
    return CryptoMockService(
      random: Random(42),
      tickInterval: const Duration(milliseconds: 10),
      initialLoadDelay: loadDelay,
      initialLoadFailureRate: failureRate,
      anomalyRate: anomalyRate,
    );
  }

  // Luôn dispose sau mỗi test -> tránh Timer/Controller rò rỉ giữa các test.
  tearDown(() => service.dispose());

  group('Future: fetchInitialPrices', () {
    test('trả về giá gốc của tất cả coin', () async {
      service = createService();

      final prices = await service.fetchInitialPrices();

      expect(
        prices.map((p) => p.symbol),
        containsAll(CryptoMockService.basePrices.keys),
      );
      for (final p in prices) {
        expect(p.price, CryptoMockService.basePrices[p.symbol]);
        expect(p.changePercent, 0.0);
      }
    });

    test('ném CryptoServiceException khi giả lập lỗi mạng', () {
      service = createService(failureRate: 1.0);

      expect(
        service.fetchInitialPrices(),
        throwsA(isA<CryptoServiceException>()),
      );
    });

    test('Future.wait chạy song song (không cộng dồn độ trễ)', () async {
      const delay = Duration(milliseconds: 200);
      service = createService(loadDelay: delay);
      final coinCount = CryptoMockService.basePrices.length;

      final stopwatch = Stopwatch()..start();
      await service.fetchInitialPrices();
      stopwatch.stop();

      // Nếu chạy tuần tự sẽ mất ~ delay * coinCount (800ms).
      expect(stopwatch.elapsed, lessThan(delay * coinCount));
    });
  });

  group('Stream: priceStream', () {
    test('là broadcast stream (nhiều listener cùng nghe được)', () {
      service = createService();

      expect(service.priceStream.isBroadcast, isTrue);
    });

    test('mỗi tick phát giá cho mọi coin, dao động trong ±2%', () async {
      service = createService();
      final coinCount = CryptoMockService.basePrices.length;

      final events = await service.priceStream.take(coinCount * 2).toList();

      expect(events.length, coinCount * 2);
      expect(
        events.map((e) => e.symbol).toSet(),
        CryptoMockService.basePrices.keys.toSet(),
      );
      for (final e in events) {
        expect(
          e.changePercent.abs(),
          lessThanOrEqualTo(CryptoMockService.normalMaxChange),
        );
      }
    });

    test('Timer chỉ chạy khi có listener (onListen / onCancel)', () async {
      service = createService();
      expect(service.isRunning, isFalse);

      final sub = service.priceStream.listen((_) {});
      expect(service.isRunning, isTrue);

      await sub.cancel();
      expect(service.isRunning, isFalse);
    });

    test('dữ liệu nhiễu bị PriceTransformer chuyển thành lỗi', () {
      service = createService(anomalyRate: 1.0);

      expect(
        service.priceStream.transform(PriceTransformer.sanitize()),
        emitsError(isA<PriceAnomalyException>()),
      );
    });

    test('kết hợp transformer: dữ liệu hợp lệ được làm tròn', () async {
      service = createService();

      final CryptoPrice first = await service.priceStream
          .transform(PriceTransformer.sanitize())
          .first;

      expect(first.price, (first.price * 100).roundToDouble() / 100);
      expect(
        first.changePercent,
        (first.changePercent * 100).roundToDouble() / 100,
      );
    });
  });

  group('dispose', () {
    test('đóng Stream -> listener nhận sự kiện done', () async {
      service = createService();
      final done = expectLater(service.priceStream, emitsThrough(emitsDone));

      service.dispose();

      await done;
      expect(service.isDisposed, isTrue);
      expect(service.isRunning, isFalse);
    });

    test('gọi fetchInitialPrices sau dispose -> StateError', () {
      service = createService()..dispose();

      expect(service.fetchInitialPrices(), throwsStateError);
    });

    test('gọi dispose nhiều lần vẫn an toàn', () {
      service = createService();

      service.dispose();
      expect(service.dispose, returnsNormally);
    });
  });
}

