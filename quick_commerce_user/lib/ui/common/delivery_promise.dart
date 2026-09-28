import '../../core/utils/date_labels.dart';
import '../../domain/model/order.dart';

/// How the delivery wait is worded, in one place.
///
/// This is quick commerce: packing plus two short rides, so the promise is
/// minutes. The number itself always comes from the server's
/// `pricing.deliveryPromiseMinutes` — never from a constant here — so every
/// surface quotes the same figure and a business change moves them together.
///
/// The web cart once showed "35-40 mins" in a header directly above an option
/// saying "about 6 mins". Routing every wait through this avoids a repeat.
abstract final class DeliveryPromise {
  /// What to say about when an order will arrive.
  ///
  /// A booking is a live order that is not in progress yet, so it is described
  /// by its window — "Arriving tomorrow, 07:00 – 08:00" — rather than counted
  /// down from the instant-order ETA. Counting a booking from `placedAt + eta`
  /// reads as arriving in minutes and then as permanently overdue, and hours
  /// rendered as a minute count is meaningless.
  static String forOrder(Order order, {DateTime? now}) {
    final at = now ?? DateTime.now();

    if (order.isBookingAt(at)) {
      final day = DateLabels.relativeDay(order.scheduledAt!, now: at);
      final window = order.hasSlot
          ? order.slotWindow
          : DateLabels.clock(order.scheduledAt!);
      return 'Arriving ${day.toLowerCase()}, $window';
    }

    return label(order.etaMinutes);
  }

  /// Shown only until the server's quote lands. Deliberately vague rather than
  /// a specific wrong number — a stale precise figure is worse than none.
  static const _pending = 'Calculating…';

  /// `12 mins` — the plain figure, for a header or a badge.
  static String? minutesLabel(int? promiseMinutes) {
    if (promiseMinutes == null || promiseMinutes <= 0) return null;
    return '$promiseMinutes ${promiseMinutes == 1 ? 'min' : 'mins'}';
  }

  /// `Arriving in about 12 mins` — the full sentence for a summary row.
  static String label(int? promiseMinutes) {
    final minutes = minutesLabel(promiseMinutes);
    return minutes == null ? _pending : 'Arriving in about $minutes';
  }
}
