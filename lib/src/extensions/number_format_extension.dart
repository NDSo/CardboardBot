import 'package:intl/intl.dart';

extension NumberFormatExtension on NumberFormat {
  num? tryParse(String? text) {
    if (text == null) return null;
    try {
      return parse(text);
    } catch (e) {
      return null;
    }
  }
}
