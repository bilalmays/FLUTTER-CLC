import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:car_luxe_cleaning_flutter/shared/models/subscription.dart';
import 'package:flutter/material.dart';

class SubscriptionPlanMeta {
  const SubscriptionPlanMeta({
    required this.label,
    required this.color,
    required this.price,
    required this.monthlyAllowance,
  });

  final String label;
  final Color color;
  final int price;
  final int monthlyAllowance;
}

const subscriptionPlanMeta = {
  SubscriptionPlan.platinium: SubscriptionPlanMeta(
    label: 'Platinium',
    color: AppColors.navy,
    price: 399,
    monthlyAllowance: 4,
  ),
  SubscriptionPlan.carbone: SubscriptionPlanMeta(
    label: 'Carbone',
    color: Color(0xFF52525B),
    price: 249,
    monthlyAllowance: 3,
  ),
  SubscriptionPlan.gold: SubscriptionPlanMeta(
    label: 'Or',
    color: AppColors.gold,
    price: 179,
    monthlyAllowance: 2,
  ),
};

SubscriptionPlanMeta metaForPlan(SubscriptionPlan plan) =>
    subscriptionPlanMeta[plan]!;
