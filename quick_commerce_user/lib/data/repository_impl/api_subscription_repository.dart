import '../../core/errors/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../domain/model/payment_method.dart';
import '../../domain/model/product_subscription.dart';
import '../../domain/repository/subscription_repository.dart';
import '../dto/json_reader.dart';
import '../dto/subscription_dto.dart';
import '../mapper/subscription_mapper.dart';
import 'api_paths.dart';

class ApiSubscriptionRepository implements SubscriptionRepository {
  ApiSubscriptionRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<ProductSubscription>> list() async {
    final json = await _client.get(ApiPaths.subscriptions, requiresAuth: true);
    if (json is! Map<String, dynamic>) return const [];
    return SubscriptionMapper.toDomainList(
      json.objects('subscriptions').map(SubscriptionDto.fromJson).toList(),
    );
  }

  @override
  Future<ProductSubscription> getById(String subscriptionId) async {
    final json = await _client.get(
      ApiPaths.subscription(subscriptionId),
      requiresAuth: true,
    );
    if (json is! Map<String, dynamic>) {
      throw const ParseException('Unexpected subscription response.');
    }
    // This endpoint returns the schedule alongside the subscription, so both
    // are folded into one domain object rather than needing a second call.
    return SubscriptionMapper.toDomain(
      SubscriptionDto.fromJson(
        json.mapAt('subscription'),
        occurrences: _occurrenceDtos(json),
      ),
    );
  }

  @override
  Future<ProductSubscription> create({
    required String restaurantId,
    required String itemId,
    required int quantity,
    required SubscriptionFrequency frequency,
    required String deliveryTime,
    required DateTime startDate,
    required String addressId,
    String? variantId,
    List<int> daysOfWeek = const [],
    int? dayOfMonth,
    PaymentMethod method = PaymentMethod.cash,
  }) async {
    final json = await _client.post(
      ApiPaths.subscriptions,
      body: {
        'restaurantId': restaurantId,
        'itemId': itemId,
        'quantity': quantity,
        'frequency': frequency.wireValue,
        'deliveryTime': deliveryTime,
        'startDate': SubscriptionMapper.dateOnly(startDate),
        'addressId': addressId,
        'paymentMethod': SubscriptionMapper.paymentWireValue(method),
        if (variantId != null && variantId.trim().isNotEmpty)
          'variantId': variantId.trim(),
        // Each recurrence field is only sent for the frequency that uses it;
        // the backend ignores the other, but sending neither keeps it honest.
        if (frequency.needsDaysOfWeek) 'daysOfWeek': daysOfWeek,
        if (frequency.needsDayOfMonth && dayOfMonth != null)
          'dayOfMonth': dayOfMonth,
      },
      requiresAuth: true,
    );
    return _single(json);
  }

  @override
  Future<ProductSubscription> update(
    String subscriptionId, {
    SubscriptionStatus? status,
    int? quantity,
    String? deliveryTime,
    String? addressId,
  }) async {
    final json = await _client.patch(
      ApiPaths.subscription(subscriptionId),
      body: {
        'status': ?status?.wireValue,
        'quantity': ?quantity,
        'deliveryTime': ?deliveryTime,
        if (addressId != null && addressId.isNotEmpty) 'addressId': addressId,
      },
      requiresAuth: true,
    );
    return _single(json);
  }

  @override
  Future<void> cancel(String subscriptionId) =>
      _client.delete(ApiPaths.subscription(subscriptionId), requiresAuth: true);

  @override
  Future<List<SubscriptionOccurrence>> occurrences(
    String subscriptionId,
  ) async {
    final json = await _client.get(
      ApiPaths.subscriptionOccurrences(subscriptionId),
      requiresAuth: true,
    );
    if (json is! Map<String, dynamic>) return const [];
    return SubscriptionMapper.occurrencesToDomain(_occurrenceDtos(json));
  }

  @override
  Future<SubscriptionOccurrence> cancelOccurrence(
    String subscriptionId,
    String occurrenceId, {
    String? reason,
  }) async {
    final json = await _client.post(
      ApiPaths.subscriptionOccurrenceCancel(subscriptionId, occurrenceId),
      body: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
      requiresAuth: true,
    );
    if (json is! Map<String, dynamic>) {
      throw const ParseException('Unexpected delivery response.');
    }
    return SubscriptionMapper.occurrenceToDomain(
      SubscriptionOccurrenceDto.fromJson(json.mapAt('occurrence')),
    );
  }

  List<SubscriptionOccurrenceDto> _occurrenceDtos(Map<String, dynamic> json) =>
      json.objects('occurrences').map(SubscriptionOccurrenceDto.fromJson).toList();

  ProductSubscription _single(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const ParseException('Unexpected subscription response.');
    }
    return SubscriptionMapper.toDomain(
      SubscriptionDto.fromJson(json.mapAt('subscription')),
    );
  }
}
