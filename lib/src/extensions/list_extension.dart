import 'dart:math';

import 'package:collection/collection.dart';

extension ListExtension<T> on List<T> {
  List<T> subListSafe(int start, [int? end]) {
    return sublist(start, end == null ? null : min(length, end));
  }

  List<T> sorted([int Function(T a, T b)? compare]) {
    mergeSort(this, compare: compare);
    return this;
  }

  List<List<T>> toChunks(int chunkSize) {
    List<List<T>> chunks = [];
    List<T> thisList = List.of(this);

    while (thisList.isNotEmpty) {
      chunks.add(thisList.take(chunkSize).toList());
      thisList = thisList.skip(chunkSize).toList();
    }

    return chunks;
  }
}
