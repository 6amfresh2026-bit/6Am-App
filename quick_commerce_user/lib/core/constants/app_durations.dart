/// Motion timings. One place so the whole app feels coherent.
abstract final class AppDurations {
  static const instant = Duration(milliseconds: 90);
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 450);

  static const staggerStep = Duration(milliseconds: 40);
  static const searchDebounce = Duration(milliseconds: 300);
  static const bannerAutoScroll = Duration(seconds: 4);
  static const toast = Duration(seconds: 2, milliseconds: 500);
  static const toastAnimation = Duration(milliseconds: 250);
  static const trackingPoll = Duration(seconds: 8);
  static const splashHold = Duration(milliseconds: 1400);
}
