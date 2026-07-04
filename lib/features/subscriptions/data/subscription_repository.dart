import 'package:car_luxe_cleaning_flutter/features/subscriptions/data/subscription_seed_data.dart';
import 'package:car_luxe_cleaning_flutter/features/subscriptions/domain/subscription_plan_meta.dart';
import 'package:car_luxe_cleaning_flutter/shared/models/subscription.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => LocalSubscriptionRepository(),
);

abstract class SubscriptionRepository {
  Future<List<SubscriptionBundle>> listSubscriptions();
  Future<SubscriptionBundle> addVisit(String subscriptionId, DateTime date);
  Future<int> importExcelSeed();
  Future<SubscriptionBundle> createSubscription({
    required SubscriptionBundle source,
    required SubscriptionPlan plan,
    required DateTime startDate,
    required int amountPaid,
  });
}

class LocalSubscriptionRepository implements SubscriptionRepository {
  LocalSubscriptionRepository() : _bundles = buildSeedSubscriptionBundles();

  final List<SubscriptionBundle> _bundles;

  @override
  Future<List<SubscriptionBundle>> listSubscriptions() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return List.unmodifiable(_bundles);
  }

  @override
  Future<SubscriptionBundle> addVisit(
    String subscriptionId,
    DateTime date,
  ) async {
    final index = _bundles.indexWhere(
      (bundle) => bundle.subscription.id == subscriptionId,
    );
    if (index < 0) throw StateError('Abonnement introuvable.');

    final bundle = _bundles[index];
    final visit = SubscriptionVisit(
      id: 'visit-$subscriptionId-${date.millisecondsSinceEpoch}',
      subscriptionId: subscriptionId,
      clientId: bundle.client.id,
      vehicleId: bundle.vehicle.id,
      visitDate: date,
      createdAt: DateTime.now(),
      notes: 'Passage ajoute depuis Flutter',
    );

    final updated = SubscriptionBundle(
      subscription: bundle.subscription,
      client: bundle.client,
      vehicle: bundle.vehicle,
      visits: [...bundle.visits, visit]
        ..sort((a, b) => a.visitDate.compareTo(b.visitDate)),
    );
    _bundles[index] = updated;
    return updated;
  }

  @override
  Future<int> importExcelSeed() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    var created = 0;
    for (final bundle in buildSeedSubscriptionBundles()) {
      final exists = _bundles.any(
        (item) => item.subscription.id == bundle.subscription.id,
      );
      if (exists) continue;
      _bundles.add(bundle);
      created += 1;
    }
    _bundles.sort(
      (a, b) => a.subscription.endDate.compareTo(b.subscription.endDate),
    );
    return created;
  }

  @override
  Future<SubscriptionBundle> createSubscription({
    required SubscriptionBundle source,
    required SubscriptionPlan plan,
    required DateTime startDate,
    required int amountPaid,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final now = DateTime.now();
    final meta = metaForPlan(plan);
    final cleanStart = DateTime(startDate.year, startDate.month, startDate.day);
    final subscription = Subscription(
      id: 'subscription-${now.microsecondsSinceEpoch}',
      clientId: source.client.id,
      vehicleId: source.vehicle.id,
      plan: plan,
      startDate: cleanStart,
      endDate: DateTime(cleanStart.year + 1, cleanStart.month, cleanStart.day),
      amountPaid: amountPaid,
      totalWash: 0,
      monthlyAllowance: meta.monthlyAllowance,
      paymentType: PaymentType.full,
      status: SubscriptionStatus.active,
      createdAt: now,
      updatedAt: now,
      notes: 'Cree depuis Flutter',
    );
    final bundle = SubscriptionBundle(
      subscription: subscription,
      client: source.client,
      vehicle: source.vehicle,
      visits: const [],
    );
    _bundles.insert(0, bundle);
    return bundle;
  }
}
