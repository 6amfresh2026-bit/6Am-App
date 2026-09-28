import '../../core/utils/date_labels.dart';
import '../model/product_subscription.dart';

/// Business rules for recurring product deliveries: how a recurrence reads in
/// plain language, when the next delivery lands, and whether a draft is valid.
///
/// The validation here deliberately mirrors the backend's own validator so the
/// customer sees the problem in the form instead of a 400 after submitting.
class SubscriptionScheduleService {
  const SubscriptionScheduleService();

  /// `Daily at 7:00 AM` / `Every Mon, Wed & Fri at 7:00 AM` /
  /// `On the 15th of each month at 7:00 AM`.
  String describe(ProductSubscription subscription) {
    final time = DateLabels.clockFromWire(subscription.deliveryTime);
    return '${describeRecurrence(
      frequency: subscription.frequency,
      daysOfWeek: subscription.daysOfWeek,
      dayOfMonth: subscription.dayOfMonth,
    )} at $time';
  }

  String describeRecurrence({
    required SubscriptionFrequency frequency,
    List<int> daysOfWeek = const [],
    int? dayOfMonth,
  }) =>
      switch (frequency) {
        SubscriptionFrequency.daily => 'Daily',
        SubscriptionFrequency.weekly => _weeklyLabel(daysOfWeek),
        SubscriptionFrequency.monthly =>
          'On the ${_ordinal(dayOfMonth ?? 1)} of each month',
      };

  String _weeklyLabel(List<int> daysOfWeek) {
    if (daysOfWeek.isEmpty) return 'Weekly';
    final sorted = [...daysOfWeek]..sort();
    final names = sorted.map(DateLabels.weekdayShort).toList();
    if (names.length == 1) return 'Every ${names.first}';
    // "Mon, Wed & Fri" reads better than a trailing comma before the last day.
    final last = names.removeLast();
    return 'Every ${names.join(', ')} & $last';
  }

  String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    return switch (day % 10) {
      1 => '${day}st',
      2 => '${day}nd',
      3 => '${day}rd',
      _ => '${day}th',
    };
  }

  /// The soonest delivery still ahead of [now]. Null when the series has no
  /// scheduled occurrence left — paused, cancelled, or not yet regenerated.
  SubscriptionOccurrence? nextDelivery(
    ProductSubscription subscription, {
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final upcoming = subscription.occurrences
        .where((o) => o.isScheduled && !o.scheduledDate.isBefore(_startOfDay(at)))
        .toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  /// Deliveries from today onward, soonest first.
  ///
  /// The occurrences endpoint returns the whole history, not just what is
  /// coming — so the two are separated here rather than in the widget.
  List<SubscriptionOccurrence> upcomingFrom(
    ProductSubscription subscription, {
    DateTime? now,
  }) {
    final today = _startOfDay(now ?? DateTime.now());
    return subscription.occurrences
        .where((o) => !o.scheduledDate.isBefore(today))
        .toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
  }

  /// Deliveries already past, most recent first — a record of what happened,
  /// including the ones that were skipped or failed.
  List<SubscriptionOccurrence> historyBefore(
    ProductSubscription subscription, {
    DateTime? now,
  }) {
    final today = _startOfDay(now ?? DateTime.now());
    return subscription.occurrences
        .where((o) => o.scheduledDate.isBefore(today))
        .toList()
      ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
  }

  /// Field errors for a new subscription, keyed the way the form reads them.
  /// Empty means the draft is safe to submit.
  Map<String, String> validateDraft({
    required SubscriptionFrequency frequency,
    required String deliveryTime,
    required DateTime? startDate,
    required String addressId,
    required int quantity,
    List<int> daysOfWeek = const [],
    int? dayOfMonth,
    DateTime? now,
  }) {
    final errors = <String, String>{};

    if (quantity < 1) {
      errors['quantity'] = 'Quantity must be at least 1';
    }

    if (!isValidDeliveryTime(deliveryTime)) {
      errors['deliveryTime'] = 'Choose a delivery time';
    }

    if (startDate == null) {
      errors['startDate'] = 'Choose a start date';
    } else if (DateLabels.daysBetween(now ?? DateTime.now(), startDate) < 0) {
      // Compared by calendar day, not instant: "today" is a valid start date
      // even at 11pm, which is what the backend accepts too.
      errors['startDate'] = 'Start date cannot be in the past';
    }

    if (frequency.needsDaysOfWeek && daysOfWeek.isEmpty) {
      errors['daysOfWeek'] = 'Pick at least one day of the week';
    }

    if (frequency.needsDayOfMonth) {
      final day = dayOfMonth ?? 0;
      if (day < 1 || day > 28) {
        // 1–28 keeps the date valid in February as well.
        errors['dayOfMonth'] = 'Pick a day between 1 and 28';
      }
    }

    if (addressId.trim().isEmpty) {
      errors['addressId'] = 'Choose a delivery address';
    }

    return errors;
  }

  /// `HH:mm` in 24-hour form — the only shape the backend accepts.
  bool isValidDeliveryTime(String value) =>
      RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').hasMatch(value);

  DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
