import 'package:crypto_stream_tracker/models/crypto_price.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final timestamp = DateTime(2026, 10, 15, 9, 5, 3);
  final btc = CryptoPrice(
    symbol: 'BTC',
    price: 65000.0,
    changePercent: 1.25,
    timestamp: timestamp,
  );

  group('CryptoPrice.copyWith', () {
    test('chỉ thay đổi trường được truyền, giữ nguyên các trường khác', () {
      final updated = btc.copyWith(price: 66000.0);

      expect(updated.price, 66000.0);
      expect(updated.symbol, 'BTC');
      expect(updated.changePercent, 1.25);
      expect(updated.timestamp, timestamp);
    });

    test('trả về instance mới, object gốc không bị thay đổi (immutable)', () {
      final updated = btc.copyWith(changePercent: -3.0);

      expect(identical(updated, btc), isFalse);
      expect(btc.changePercent, 1.25);
    });

    test('không truyền tham số -> bản sao có giá trị giống hệt', () {
      final copy = btc.copyWith();

      expect(copy.symbol, btc.symbol);
      expect(copy.price, btc.price);
      expect(copy.changePercent, btc.changePercent);
      expect(copy.timestamp, btc.timestamp);
    });
  });

  group('CryptoPrice.toString', () {
    test('định dạng log ngắn gọn với dấu + khi tăng', () {
      expect(btc.toString(), '[09:05:03] BTC: 65000.00 (+1.25%)');
    });

    test('hiển thị dấu - khi giảm', () {
      final eth = CryptoPrice(
        symbol: 'ETH',
        price: 3199.5,
        changePercent: -3.5,
        timestamp: DateTime(2026, 1, 1, 23, 59, 0),
      );

      expect(eth.toString(), '[23:59:00] ETH: 3199.50 (-3.50%)');
    });
  });
}

