/// زمان واقعی دستگاه؛ بدون مقدار ساختگی یا ثابت.
/// در حالت آفلاین، منبع زمان ساعت سیستم همان دستگاه است.
class RealClock {
  static DateTime now() => DateTime.now();
  static int nowMillis() => now().millisecondsSinceEpoch;
}
