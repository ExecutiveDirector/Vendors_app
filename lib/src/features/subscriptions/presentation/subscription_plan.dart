class SubscriptionPlan {
  final int planId;
  final String planName;
  final double? price;
  final String frequency;
  final int frequencyInterval;
  final double discountPercentage;
  final double minimumOrderValue;
  final bool freeDelivery;
  final bool prioritySupport;

  SubscriptionPlan({
    required this.planId,
    required this.planName,
    this.price,
    required this.frequency,
    required this.frequencyInterval,
    required this.discountPercentage,
    required this.minimumOrderValue,
    required this.freeDelivery,
    required this.prioritySupport,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      planId: json['id'],
      planName: json['name'],
      price: (json['price'] as num?)?.toDouble(),
      frequency: json['frequency'] ?? 'Monthly',
      frequencyInterval: json['frequency_interval'] ?? 1,
      discountPercentage: (json['discount_percentage'] ?? 0).toDouble(),
      minimumOrderValue: (json['min_order_value'] ?? 0).toDouble(),
      freeDelivery: json['free_delivery'] ?? false,
      prioritySupport: json['priority_support'] ?? false,
    );
  }
}
