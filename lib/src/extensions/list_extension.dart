import 'dart:math';

extension ListExtension<T> on List<T> {
  List<T> subListSafe(int start, [int? end]) {
    return sublist(start, end == null ? null : min(length, end));
  }
}
