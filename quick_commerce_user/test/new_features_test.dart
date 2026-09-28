import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_user/core/utils/date_labels.dart';
import 'package:quick_commerce_user/data/dto/monthly_list_dto.dart';
import 'package:quick_commerce_user/data/dto/subscription_dto.dart';
import 'package:quick_commerce_user/data/dto/survey_dto.dart';
import 'package:quick_commerce_user/data/mapper/monthly_list_mapper.dart';
import 'package:quick_commerce_user/data/mapper/subscription_mapper.dart';
import 'package:quick_commerce_user/data/dto/product_dto.dart';
import 'package:quick_commerce_user/data/mapper/product_mapper.dart';
import 'package:quick_commerce_user/data/mapper/survey_mapper.dart';
import 'package:quick_commerce_user/domain/model/monthly_list.dart';
import 'package:quick_commerce_user/domain/model/payment_method.dart';
import 'package:quick_commerce_user/domain/model/product_subscription.dart';
import 'package:quick_commerce_user/domain/model/survey.dart';
import 'package:quick_commerce_user/domain/model/product.dart';
import 'package:quick_commerce_user/domain/service/catalog_grouping_service.dart';
import 'package:quick_commerce_user/domain/service/subscription_schedule_service.dart';

/// Covers the rules that would misbehave silently: the subscription
/// cancellation cutoff (the app must never offer a cancel the server refuses),
/// schedule validation, and the wire shapes the new endpoints return.
void main() {
  group('subscription cancellation cutoff', () {
    SubscriptionOccurrence occurrence({
      DateTime? date,
      OccurrenceStatus status = OccurrenceStatus.scheduled,
    }) =>
        SubscriptionOccurrence(
          id: 'o1',
          scheduledDate: date ?? DateTime(2026, 9, 10),
          deliveryTime: '07:00',
          status: status,
        );

    test('the night before is still cancellable, right up to midnight', () {
      final o = occurrence(date: DateTime(2026, 9, 10));
      expect(o.canCancelAt(DateTime(2026, 9, 9, 23, 59, 59)), isTrue);
    });

    test('midnight starting the delivery day closes the window', () {
      final o = occurrence(date: DateTime(2026, 9, 10));
      // Exactly the cutoff — the backend uses >=, so this must be refused.
      expect(o.canCancelAt(DateTime(2026, 9, 10)), isFalse);
    });

    test('once the delivery day has begun it is too late', () {
      final o = occurrence(date: DateTime(2026, 9, 10));
      expect(o.canCancelAt(DateTime(2026, 9, 10, 0, 0, 1)), isFalse);
      expect(o.canCancelAt(DateTime(2026, 9, 10, 6)), isFalse);
    });

    test('the delivery time of day does not widen the window', () {
      // A 23:00 delivery still cannot be cancelled at 09:00 the same day.
      final o = occurrence(date: DateTime(2026, 9, 10));
      expect(o.canCancelAt(DateTime(2026, 9, 10, 9)), isFalse);
    });

    test('an already-placed or cancelled delivery is never cancellable', () {
      for (final status in [
        OccurrenceStatus.orderPlaced,
        OccurrenceStatus.cancelled,
        OccurrenceStatus.failed,
      ]) {
        final o = occurrence(date: DateTime(2026, 9, 10), status: status);
        expect(o.canCancelAt(DateTime(2026, 9, 1)), isFalse, reason: '$status');
      }
    });
  });

  group('SubscriptionScheduleService validation', () {
    const service = SubscriptionScheduleService();
    final now = DateTime(2026, 9, 3, 14);

    Map<String, String> validate({
      SubscriptionFrequency frequency = SubscriptionFrequency.daily,
      String time = '07:00',
      DateTime? start,
      String addressId = 'a1',
      int quantity = 1,
      List<int> days = const [],
      int? dayOfMonth,
    }) =>
        service.validateDraft(
          frequency: frequency,
          deliveryTime: time,
          startDate: start ?? DateTime(2026, 9, 3),
          addressId: addressId,
          quantity: quantity,
          daysOfWeek: days,
          dayOfMonth: dayOfMonth,
          now: now,
        );

    test('a well-formed daily draft passes', () {
      expect(validate(), isEmpty);
    });

    test('today counts as a valid start date even late in the day', () {
      // The backend compares calendar days, so 2pm on the start date is fine.
      expect(validate(start: DateTime(2026, 9, 3)), isEmpty);
    });

    test('a past start date is rejected', () {
      expect(validate(start: DateTime(2026, 9, 2)), contains('startDate'));
    });

    test('weekly needs at least one day', () {
      expect(
        validate(frequency: SubscriptionFrequency.weekly),
        contains('daysOfWeek'),
      );
      expect(
        validate(frequency: SubscriptionFrequency.weekly, days: [1, 3]),
        isEmpty,
      );
    });

    test('monthly is capped at the 28th so February always has the day', () {
      expect(
        validate(frequency: SubscriptionFrequency.monthly, dayOfMonth: 29),
        contains('dayOfMonth'),
      );
      expect(
        validate(frequency: SubscriptionFrequency.monthly, dayOfMonth: 28),
        isEmpty,
      );
    });

    test('a malformed delivery time is rejected', () {
      for (final bad in ['7:00', '25:00', '07:60', 'morning', '']) {
        expect(validate(time: bad), contains('deliveryTime'), reason: bad);
      }
    });

    test('a missing address is rejected', () {
      expect(validate(addressId: '  '), contains('addressId'));
    });
  });

  group('SubscriptionScheduleService description', () {
    const service = SubscriptionScheduleService();

    ProductSubscription sub({
      SubscriptionFrequency frequency = SubscriptionFrequency.daily,
      List<int> days = const [],
      int? dayOfMonth,
      String time = '07:00',
    }) =>
        ProductSubscription(
          id: 's1',
          restaurantId: 'r1',
          itemId: 'i1',
          quantity: 1,
          frequency: frequency,
          deliveryTime: time,
          startDate: DateTime(2026, 9, 3),
          addressId: 'a1',
          status: SubscriptionStatus.active,
          daysOfWeek: days,
          dayOfMonth: dayOfMonth,
        );

    test('daily', () {
      expect(service.describe(sub()), 'Daily at 7:00 AM');
    });

    test('weekly lists the days in order', () {
      expect(
        service.describe(
          sub(frequency: SubscriptionFrequency.weekly, days: [5, 1, 3]),
        ),
        'Every Mon, Wed & Fri at 7:00 AM',
      );
    });

    test('monthly uses an ordinal', () {
      expect(
        service.describe(
          sub(
            frequency: SubscriptionFrequency.monthly,
            dayOfMonth: 11,
            time: '18:30',
          ),
        ),
        'On the 11th of each month at 6:30 PM',
      );
    });

    test('nextDelivery picks the soonest still-scheduled delivery', () {
      final now = DateTime(2026, 9, 3, 10);
      final subscription = ProductSubscription(
        id: 's1',
        restaurantId: 'r1',
        itemId: 'i1',
        quantity: 1,
        frequency: SubscriptionFrequency.daily,
        deliveryTime: '07:00',
        startDate: DateTime(2026, 9, 1),
        addressId: 'a1',
        status: SubscriptionStatus.active,
        occurrences: [
          SubscriptionOccurrence(
            id: 'past',
            scheduledDate: DateTime(2026, 9, 1),
            deliveryTime: '07:00',
            status: OccurrenceStatus.orderPlaced,
          ),
          SubscriptionOccurrence(
            id: 'skipped',
            scheduledDate: DateTime(2026, 9, 4),
            deliveryTime: '07:00',
            status: OccurrenceStatus.cancelled,
          ),
          SubscriptionOccurrence(
            id: 'next',
            scheduledDate: DateTime(2026, 9, 5),
            deliveryTime: '07:00',
            status: OccurrenceStatus.scheduled,
          ),
        ],
      );

      expect(service.nextDelivery(subscription, now: now)?.id, 'next');
    });
  });

  group('DateLabels', () {
    test('24h wire times become readable clock times', () {
      expect(DateLabels.clockFromWire('07:00'), '7:00 AM');
      expect(DateLabels.clockFromWire('00:05'), '12:05 AM');
      expect(DateLabels.clockFromWire('12:00'), '12:00 PM');
      expect(DateLabels.clockFromWire('23:45'), '11:45 PM');
    });

    test('a malformed time is shown as-is rather than silently wrong', () {
      expect(DateLabels.clockFromWire('nope'), 'nope');
      expect(DateLabels.clockFromWire('99:99'), '99:99');
    });

    test('relative days ignore the time of day', () {
      final now = DateTime(2026, 9, 3, 23, 30);
      expect(DateLabels.relativeDay(DateTime(2026, 9, 3, 1), now: now), 'Today');
      expect(
        DateLabels.relativeDay(DateTime(2026, 9, 4, 1), now: now),
        'Tomorrow',
      );
    });
  });

  group('wire shapes', () {
    test('a monthly list parses, including a populated restaurant', () {
      final list = MonthlyListMapper.toDomain(
        MonthlyListDto.fromJson({
          '_id': 'l1',
          'name': 'Groceries',
          'restaurantId': {'_id': 'r1', 'name': 'Amul Store'},
          'isActive': true,
          'lastOrderedAt': '2026-09-01T04:30:00.000Z',
          'items': [
            {'itemId': 'i1', 'quantity': 2, 'name': 'Milk 1L'},
            {'itemId': 'i2', 'quantity': 1, 'variantId': 'v1', 'name': 'Bread'},
          ],
        }),
      );

      expect(list.id, 'l1');
      expect(list.restaurantId, 'r1');
      expect(list.restaurantName, 'Amul Store');
      expect(list.itemCount, 2);
      expect(list.totalQuantity, 3);
      expect(list.canOrder, isTrue);
      expect(list.items[1].lineId, 'i2::v1');
    });

    test('an inactive or empty list cannot be ordered', () {
      final inactive = MonthlyListMapper.toDomain(
        MonthlyListDto.fromJson({
          '_id': 'l1',
          'isActive': false,
          'items': [
            {'itemId': 'i1', 'quantity': 1},
          ],
        }),
      );
      expect(inactive.canOrder, isFalse);

      final empty = MonthlyListMapper.toDomain(
        MonthlyListDto.fromJson({'_id': 'l2', 'items': []}),
      );
      expect(empty.canOrder, isFalse);
    });

    test('list items serialise without an empty variantId', () {
      expect(
        MonthlyListMapper.itemToJson(
          const MonthlyListItem(itemId: 'i1', quantity: 2),
        ),
        {'itemId': 'i1', 'quantity': 2},
      );
      expect(
        MonthlyListMapper.itemToJson(
          const MonthlyListItem(itemId: 'i1', quantity: 2, variantId: 'v1'),
        ),
        {'itemId': 'i1', 'quantity': 2, 'variantId': 'v1'},
      );
    });

    test('a subscription parses with its schedule', () {
      final subscription = SubscriptionMapper.toDomain(
        SubscriptionDto.fromJson(
          {
            '_id': 's1',
            'restaurantId': 'r1',
            'itemId': 'i1',
            'itemName': 'Milk 1L',
            'quantity': 2,
            'frequency': 'weekly',
            'daysOfWeek': [1, 3, 5],
            'deliveryTime': '07:00',
            'startDate': '2026-09-01T00:00:00.000Z',
            'addressId': 'a1',
            'paymentMethod': 'cash',
            'status': 'paused',
          },
          occurrences: [
            SubscriptionOccurrenceDto.fromJson({
              '_id': 'o2',
              'scheduledDate': '2026-09-05T00:00:00.000Z',
              'deliveryTime': '07:00',
              'status': 'scheduled',
            }),
            SubscriptionOccurrenceDto.fromJson({
              '_id': 'o1',
              'scheduledDate': '2026-09-03T00:00:00.000Z',
              'deliveryTime': '07:00',
              'status': 'order_placed',
              'orderId': 'ord1',
            }),
          ],
        ),
      );

      expect(subscription.frequency, SubscriptionFrequency.weekly);
      expect(subscription.daysOfWeek, [1, 3, 5]);
      expect(subscription.status, SubscriptionStatus.paused);
      expect(subscription.canResume, isTrue);
      expect(subscription.paymentMethod, PaymentMethod.cash);
      // Sorted soonest-first regardless of the order they arrived in.
      expect(subscription.occurrences.first.id, 'o1');
      expect(subscription.occurrences.first.hasOrder, isTrue);
      expect(subscription.upcoming.single.id, 'o2');
    });

    test('subscriptions never send a payment method the API rejects', () {
      // The endpoint accepts only cash | razorpay | wallet.
      const allowed = {'cash', 'razorpay', 'wallet'};
      for (final method in PaymentMethod.values) {
        expect(
          allowed,
          contains(SubscriptionMapper.paymentWireValue(method)),
          reason: method.name,
        );
      }
    });

    test('start dates are sent date-only, never shifted by a UTC conversion', () {
      expect(SubscriptionMapper.dateOnly(DateTime(2026, 9, 1, 0, 30)), '2026-09-01');
      expect(SubscriptionMapper.dateOnly(DateTime(2026, 12, 9)), '2026-12-09');
    });

    test('a survey parses and skips unanswerable choice questions', () {
      final survey = SurveyMapper.toDomain(
        SurveyDto.fromJson({
          '_id': 'sv1',
          'title': 'Welcome',
          'questions': [
            {'_id': 'q1', 'text': 'How did you hear?', 'type': 'text'},
            {
              '_id': 'q2',
              'text': 'Pick one',
              'type': 'single-choice',
              'options': ['A', 'B'],
            },
            // A choice question with no options cannot be rendered.
            {'_id': 'q3', 'text': 'Broken', 'type': 'multiple-choice'},
            {'_id': 'q4', 'text': 'Rate us', 'type': 'rating'},
          ],
        }),
      );

      expect(survey.questions, hasLength(4));
      expect(survey.answerable.map((q) => q.id), ['q1', 'q2', 'q4']);
      expect(survey.isEmpty, isFalse);
    });

    test('survey answers keep their type on the wire', () {
      expect(
        SurveyMapper.answerToJson(
          const SurveyAnswer(questionId: 'q1', value: 'Instagram'),
        ),
        {'questionId': 'q1', 'answer': 'Instagram'},
      );
      expect(
        SurveyMapper.answerToJson(
          const SurveyAnswer(questionId: 'q2', value: 5),
        ),
        {'questionId': 'q2', 'answer': 5},
      );
      expect(
        SurveyMapper.answerToJson(
          const SurveyAnswer(questionId: 'q3', value: ['A', 'B']),
        ),
        {
          'questionId': 'q3',
          'answer': ['A', 'B'],
        },
      );
    });

    test('blank answers are not counted as answered', () {
      expect(
        const SurveyAnswer(questionId: 'q', value: '   ').isAnswered,
        isFalse,
      );
      expect(
        const SurveyAnswer(questionId: 'q', value: <String>[]).isAnswered,
        isFalse,
      );
      expect(const SurveyAnswer(questionId: 'q', value: 0).isAnswered, isFalse);
      expect(const SurveyAnswer(questionId: 'q', value: 4).isAnswered, isTrue);
    });
  });

  group('subscribable products', () {
    test('the menu endpoint flag is carried through to the model', () {
      final product = ProductMapper.toDomain(
        ProductDto.fromJson({
          '_id': 'p1',
          'name': 'Amul Milk 500ml',
          'price': 56,
          'restaurantId': 'r1',
          'subscriptionEnabled': true,
        }),
      );
      expect(product.subscriptionEnabled, isTrue);
    });

    test('a product without the flag is not subscribable', () {
      // /search/products omits the field entirely. Defaulting to false hides
      // the Subscribe button rather than offering one the API rejects with
      // "This product is not available for subscription".
      final product = ProductMapper.toDomain(
        ProductDto.fromJson({
          '_id': 'p1',
          'name': 'Amul Milk 500ml',
          'price': 56,
          'restaurantId': 'r1',
        }),
      );
      expect(product.subscriptionEnabled, isFalse);
    });

    test('an explicit false is respected', () {
      final product = ProductMapper.toDomain(
        ProductDto.fromJson({
          '_id': 'p1',
          'restaurantId': 'r1',
          'subscriptionEnabled': false,
        }),
      );
      expect(product.subscriptionEnabled, isFalse);
    });
  });

  group('schedule split', () {
    const service = SubscriptionScheduleService();
    final now = DateTime(2026, 9, 10, 15);

    SubscriptionOccurrence at(int day, OccurrenceStatus status) =>
        SubscriptionOccurrence(
          id: 'o$day',
          scheduledDate: DateTime(2026, 9, day),
          deliveryTime: '07:00',
          status: status,
        );

    final subscription = ProductSubscription(
      id: 's1',
      restaurantId: 'r1',
      itemId: 'i1',
      quantity: 1,
      frequency: SubscriptionFrequency.daily,
      deliveryTime: '07:00',
      startDate: DateTime(2026, 9, 8),
      addressId: 'a1',
      status: SubscriptionStatus.active,
      occurrences: [
        at(12, OccurrenceStatus.scheduled),
        at(8, OccurrenceStatus.orderPlaced),
        at(11, OccurrenceStatus.scheduled),
        at(9, OccurrenceStatus.cancelled),
        at(10, OccurrenceStatus.scheduled),
      ],
    );

    test('today counts as upcoming, not history', () {
      // The delivery is at 07:00 and it is now 15:00, but the day is still
      // "today" — it belongs with what is coming, not with the record.
      expect(
        service.upcomingFrom(subscription, now: now).map((o) => o.id),
        ['o10', 'o11', 'o12'],
      );
    });

    test('history is most recent first and keeps skipped days', () {
      expect(
        service.historyBefore(subscription, now: now).map((o) => o.id),
        ['o9', 'o8'],
      );
    });

    test('every occurrence lands in exactly one of the two lists', () {
      final up = service.upcomingFrom(subscription, now: now);
      final past = service.historyBefore(subscription, now: now);
      expect(up.length + past.length, subscription.occurrences.length);
      expect(
        {...up.map((o) => o.id)}.intersection({...past.map((o) => o.id)}),
        isEmpty,
      );
    });
  });

  group('categories derived from the catalogue', () {
    const grouping = CatalogGroupingService();

    Product item(String categoryId, String categoryName, {String image = ''}) =>
        Product(
          id: 'p-$categoryId-$categoryName-$image',
          name: 'Item',
          price: 10,
          sellerId: 'r1',
          categoryId: categoryId,
          categoryName: categoryName,
          imageUrl: image,
        );

    test('one category per distinct id, fullest first', () {
      final categories = grouping.categoriesFrom([
        item('c-burger', 'Burgers'),
        item('c-pizza', 'Pizza'),
        item('c-pizza', 'Pizza'),
        item('c-pizza', 'Pizza'),
      ]);

      expect(categories.map((c) => c.name), ['Pizza', 'Burgers']);
      expect(categories.first.itemCount, 3);
      expect(categories.first.id, 'c-pizza');
      // sortOrder follows the rendered order so the UI need not re-sort.
      expect(categories.map((c) => c.sortOrder), [0, 1]);
    });

    test('ties break alphabetically rather than arbitrarily', () {
      final categories = grouping.categoriesFrom([
        item('c-z', 'Zucchini'),
        item('c-a', 'Apples'),
      ]);
      expect(categories.map((c) => c.name), ['Apples', 'Zucchini']);
    });

    test('uncategorised products are skipped, not bucketed', () {
      // There is no backend id for "Other", so inventing one would produce a
      // category that cannot be opened.
      final categories = grouping.categoriesFrom([
        item('', ''),
        item('c-pizza', 'Pizza'),
        item('c-x', ''),
      ]);
      expect(categories.map((c) => c.id), ['c-pizza']);
    });

    test('the first product with an image supplies the tile art', () {
      final categories = grouping.categoriesFrom([
        item('c-pizza', 'Pizza'),
        item('c-pizza', 'Pizza', image: 'https://cdn/pizza.webp'),
      ]);
      expect(categories.single.imageUrl, 'https://cdn/pizza.webp');
    });

    test('an empty catalogue yields no categories', () {
      expect(grouping.categoriesFrom(const []), isEmpty);
    });
  });
}
