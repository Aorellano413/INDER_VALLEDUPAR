// lib/utils/formato_helpers.dart
class FormatoHelpers {
  static String formatearCOP(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '\$0';
    
    final sb = StringBuffer();
    final chars = digits.split('').reversed.toList();
    
    for (int i = 0; i < chars.length; i++) {
      if (i != 0 && i % 3 == 0) sb.write('.');
      sb.write(chars[i]);
    }
    
    final withDots = sb.toString().split('').reversed.join();
    return '\$$withDots';
  }
}