extension DateTimeExtension on DateTime {
  static DateTime max(DateTime a, DateTime b) {
    return a.isAfter(b) ? a : b;
  }
}
