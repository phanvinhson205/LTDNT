import 'package:flutter/material.dart';

import '../models/crypto_price.dart';

/// Widget phi trạng thái (StatelessWidget) hiển thị một dòng thông tin giá coin.
///
/// Tách riêng khỏi màn hình để đảm bảo nguyên tắc Single Responsibility:
/// `PriceTile` chỉ lo việc hiển thị, còn việc lắng nghe Future/Stream do View đảm nhiệm.
class PriceTile extends StatelessWidget {
  const PriceTile({
    super.key,
    required this.price,
    this.onTap,
  });

  /// Đối tượng dữ liệu bất biến chứa thông tin coin.
  final CryptoPrice price;

  /// Callback khi người dùng nhấn vào thẻ (tùy chọn).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isPositive = price.changePercent >= 0;
    final changeColor = isPositive ? Colors.green.shade700 : Colors.red.shade700;
    final changeBgColor = isPositive ? Colors.green.shade50 : Colors.red.shade50;
    final sign = isPositive ? '+' : '';

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildCoinAvatar(price.symbol),
        title: Row(
          children: [
            Text(
              price.symbol,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(width: 8),
            Text(
              _formatTime(price.timestamp),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '\$${price.price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: changeBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: changeColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: changeColor,
                size: 20,
              ),
              Text(
                '$sign${price.changePercent.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: changeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tạo avatar biểu tượng màu sắc riêng cho từng đồng coin.
  Widget _buildCoinAvatar(String symbol) {
    Color color;
    switch (symbol.toUpperCase()) {
      case 'BTC':
        color = Colors.orange.shade800;
        break;
      case 'ETH':
        color = Colors.indigo.shade600;
        break;
      case 'BNB':
        color = Colors.amber.shade700;
        break;
      case 'SOL':
        color = Colors.purple.shade600;
        break;
      default:
        color = Colors.blueGrey;
    }

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        symbol.length > 3 ? symbol.substring(0, 3) : symbol,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(dt.hour)}:${twoDigits(dt.minute)}:${twoDigits(dt.second)}';
  }
}

