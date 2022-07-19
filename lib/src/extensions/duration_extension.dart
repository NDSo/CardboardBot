extension DurationExtension on Duration {
  Duration operator /(num divisor) {
    return Duration(microseconds: (inMicroseconds / divisor).ceil());
  }
}