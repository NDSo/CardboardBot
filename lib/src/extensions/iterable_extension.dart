import 'package:collection/collection.dart';

typedef NullFunction<T> = T Function();

extension SmartIterable<E> on Iterable<E> {
  E? nullFunction() {
    return null;
  }

  E? tryElementAt(int index, {E? orElse}) {
    if ((index > length - 1) || index < 0) {
      return orElse;
    } else {
      return elementAt(index);
    }
  }

  E? tryFirst({E? orElse}) {
    if (isEmpty) {
      return orElse;
    } else {
      return first;
    }
  }

  E? tryLast({E? orElse}) {
    if (isEmpty) {
      return orElse;
    } else {
      return last;
    }
  }

  E? tryFirstWhere(bool Function(E element) test, {E? orElse}) {
    if (isNotEmpty && any(test)) {
      return firstWhere(test);
    } else {
      return orElse;
    }
  }

  List<List<E>> toChunks(int chunkSize) {
    List<List<E>> chunks = [];
    List<E> thisList = List.of(this);

    while (thisList.isNotEmpty) {
      chunks.add(thisList.take(chunkSize).toList());
      thisList = thisList.skip(chunkSize).toList();
    }

    return chunks;
  }

  List<E> sorted([int Function(E a, E b)? compare]) {
    List<E> thisList = List.of(this);
    mergeSort(thisList, compare: compare);
    return thisList;
  }

  Iterable<E> prependedBy(Iterable<E> other) {
    return [
      ...other,
      ...this,
    ];
  }
}

extension IterableFuture<T> on Iterable<Future<T>> {
  Future<Iterable<T>> waitAll() async {
    return await Future.wait(this);
  }
}

extension IterableNum on Iterable<num> {
  num sum() => fold(0, (previousValue, element) => previousValue + element);

  num? average() {
    if (length == 0) return null;
    return sum() / length;
  }

  num? min() {
    if (length == 0) return null;
    return reduce((value, element) => value.compareTo(element));
  }

  num? max() {
    if (length == 0) return null;
    return reduce((value, element) => -1 * value.compareTo(element));
  }
}
