import 'package:car_luxe_cleaning_flutter/shared/models/client.dart';
import 'package:car_luxe_cleaning_flutter/shared/models/vehicle.dart';

enum SubscriptionPlan { carbone, gold, platinium }

enum SubscriptionStatus { active, paused, completed, cancelled }

enum PaymentType { full, monthly }

class Subscription {
  const Subscription({
    required this.id,
    required this.clientId,
    required this.vehicleId,
    required this.plan,
    required this.startDate,
    required this.endDate,
    required this.totalWash,
    required this.monthlyAllowance,
    required this.paymentType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.amountPaid,
    this.notes,
  });

  final String id;
  final String clientId;
  final String vehicleId;
  final SubscriptionPlan plan;
  final DateTime startDate;
  final DateTime endDate;
  final int? amountPaid;
  final int totalWash;
  final int monthlyAllowance;
  final PaymentType paymentType;
  final SubscriptionStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      vehicleId: json['vehicleId'] as String,
      plan: _planFromJson(json['plan']),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      amountPaid: (json['amountPaid'] as num?)?.round(),
      totalWash: (json['totalWash'] as num? ?? 0).round(),
      monthlyAllowance: (json['monthlyAllowance'] as num? ?? 1).round(),
      paymentType: json['paymentType'] == 'monthly'
          ? PaymentType.monthly
          : PaymentType.full,
      status: _statusFromJson(json['status']),
      notes: json['notes'] as String?,
      createdAt: _dateFromJson(json['createdAt']),
      updatedAt: _dateFromJson(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'clientId': clientId,
    'vehicleId': vehicleId,
    'plan': plan.name,
    'startDate': _isoDate(startDate),
    'endDate': _isoDate(endDate),
    'amountPaid': amountPaid,
    'totalWash': totalWash,
    'monthlyAllowance': monthlyAllowance,
    'paymentType': paymentType.name,
    'status': status.name,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class SubscriptionVisit {
  const SubscriptionVisit({
    required this.id,
    required this.subscriptionId,
    required this.clientId,
    required this.vehicleId,
    required this.visitDate,
    required this.createdAt,
    this.notes,
  });

  final String id;
  final String subscriptionId;
  final String clientId;
  final String vehicleId;
  final DateTime visitDate;
  final DateTime createdAt;
  final String? notes;

  factory SubscriptionVisit.fromJson(Map<String, dynamic> json) {
    return SubscriptionVisit(
      id: json['id'] as String,
      subscriptionId: json['subscriptionId'] as String,
      clientId: json['clientId'] as String,
      vehicleId: json['vehicleId'] as String,
      visitDate: DateTime.parse(json['visitDate'] as String),
      createdAt: _dateFromJson(json['createdAt']),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'subscriptionId': subscriptionId,
    'clientId': clientId,
    'vehicleId': vehicleId,
    'visitDate': _isoDate(visitDate),
    'createdAt': createdAt.toIso8601String(),
    'notes': notes,
  };
}

class SubscriptionBundle {
  const SubscriptionBundle({
    required this.subscription,
    required this.client,
    required this.vehicle,
    required this.visits,
  });

  final Subscription subscription;
  final Client client;
  final Vehicle vehicle;
  final List<SubscriptionVisit> visits;

  DateTime? get lastVisit => visits.isEmpty ? null : visits.last.visitDate;

  DateTime get nextVisit {
    if (lastVisit != null) {
      return DateTime(lastVisit!.year, lastVisit!.month + 1, lastVisit!.day);
    }
    return subscription.startDate;
  }

  int get visitCount => visits.length;
  double get progress => (visitCount / 12).clamp(0, 1);
}

SubscriptionPlan _planFromJson(Object? value) {
  switch (value) {
    case 'carbone':
      return SubscriptionPlan.carbone;
    case 'gold':
      return SubscriptionPlan.gold;
    case 'platinium':
      return SubscriptionPlan.platinium;
    default:
      return SubscriptionPlan.gold;
  }
}

SubscriptionStatus _statusFromJson(Object? value) {
  switch (value) {
    case 'paused':
      return SubscriptionStatus.paused;
    case 'completed':
      return SubscriptionStatus.completed;
    case 'cancelled':
      return SubscriptionStatus.cancelled;
    default:
      return SubscriptionStatus.active;
  }
}

DateTime _dateFromJson(Object? value) {
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
