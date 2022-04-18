import 'package:intl/intl.dart';

final NumberFormat usdFormat = NumberFormat.simpleCurrency(name: "USD");

extension NumExtension on num {
  String toFormat(NumberFormat numberFormat) {
    return numberFormat.format(this);
  }
}
