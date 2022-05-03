import 'dart:convert';

import 'dart:math';

extension StringExtension on String {
  int toInt() => int.parse(this);

  int? tryToInt({int? orElse}) => int.tryParse(this) ?? orElse;

  String toTitleCase() {
    String string = split(" ").map((e) {
      String s = e.toLowerCase();
      s = s.replaceRange(0, 1, s.substring(0, 1).toUpperCase());
      return s;
    }) //
        .join(" ");
    return string;
  }

  List<E?> parseJsonList<E>() {
    var decoded = jsonDecode(this);
    return (decoded as List).cast<E>();
  }

  String substringSafe(int start, [int? end]) {
    return substring(start, min(length, end ?? length));
  }
}
