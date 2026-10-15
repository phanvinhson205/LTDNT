import 'package:crypto_stream_tracker/models/crypto_price.dart';
import 'package:crypto_stream_tracker/transformers/price_transformer.dart';
import 'package:flutter_test/flutter_test.dart';

CryptoPrice _price(String symbol, double price, double change) => CryptoPrice(
      symbol: symbol,
      price: price,
      changePercent: change,
      timestamp: DateTime(2026, 10, 15),
    );

void main() {
  group('PriceTransformer.sanitize', () {
    test('dữ liệu hợp lệ được làm tròn 2 chữ số thập phân', () async {
      final input = Stream.fromIterable([
        _price('BTC', 65000.126, 1.23456),
        _price('ETH', 3200.444, -5.678),
      ]);

      final output =
          await input.transform(PriceTransformer.sanitize()).toList();

      expect(output.length, 2);
      expect(output[0].price, 65000.13);
      expect(output[0].changePercent, 1.23);
      expect(output[1].price, 3200.44);
      expect(output[1].changePercent, -5.68);
    });

    test('biến động > 20% bị lọc và phát PriceAnomalyException qua addError',
        () {
      final input = Stream.fromIterable([
        _price('BTC', 65000, 1.0),
        _price('ETH', 4500, 35.0), // nhiễu tăng
        _price('SOL', 100, -25.0), // nhiễu giảm
        _price('BNB', 580, -2.0),
      ]);

      expect(
        input.transform(PriceTransformer.sanitize()),
        emitsInOrder([
          isA<CryptoPrice>().having((p) => p.symbol, 'symbol', 'BTC'),
          emitsError(
            isA<PriceAnomalyException>()
                .having((e) => e.symbol, 'symbol', 'ETH'),
          ),
          emitsError(
            isA<PriceAnomalyException>()
                .having((e) => e.symbol, 'symbol', 'SOL'),
          ),
          // Lỗi KHÔNG làm đóng Stream - sự kiện hợp lệ sau đó vẫn tới.
          isA<CryptoPrice>().having((p) => p.symbol, 'symbol', 'BNB'),
          emitsDone,
        ]),
      );
    });

    test('đúng ngưỡng 20% vẫn được coi là hợp lệ (điều kiện là > 20)', () {
      final input = Stream.fromIterable([
        _price('BTC', 65000, 20.0),
        _price('ETH', 3200, -20.0),
      ]);

      expect(
        input.transform(PriceTransformer.sanitize()),
        emitsInOrder([isA<CryptoPrice>(), isA<CryptoPrice>(), emitsDone]),
      );
    });

    test('có thể tùy chỉnh ngưỡng qua tham số threshold', () {
      final input = Stream.fromIterable([_price('BTC', 65000, 6.0)]);

      expect(
        input.transform(PriceTransformer.sanitize(threshold: 5.0)),
        emitsInOrder([emitsError(isA<PriceAnomalyException>()), emitsDone]),
      );
    });

    test('lỗi từ luồng nguồn được chuyển tiếp nguyên vẹn (handleError)', () {
      final input = Stream<CryptoPrice>.error(StateError('nguồn lỗi'));

      expect(
        input.transform(PriceTransformer.sanitize()),
        emitsInOrder([emitsError(isA<StateError>()), emitsDone]),
      );
    });
  });
}

