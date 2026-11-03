// lib/data/models/errand_private_details.dart

import 'package:equatable/equatable.dart';

/// The exact addresses and shopping list for an errand. Stored at
/// errands/{errandId}/private/details and readable only by the requester
/// and, once a bid is accepted AND the errand is funded, the runner.
/// Runners who are only browsing or bidding see the approximate area on
/// the errand itself, never these.
class ErrandPrivateDetails extends Equatable {
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;

  /// Empty for errands with no drop-off (e.g. standing in a queue).
  final String dropoffAddress;
  final double? dropoffLat;
  final double? dropoffLng;

  /// Shopping errands only: one item per line, as the requester typed it.
  final List<String> shoppingList;

  /// Anything the runner needs on the day: gate code, who to ask for,
  /// reference numbers for an admin errand.
  final String instructions;

  const ErrandPrivateDetails({
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    this.dropoffAddress = '',
    this.dropoffLat,
    this.dropoffLng,
    this.shoppingList = const [],
    this.instructions = '',
  });

  bool get hasDropoff => dropoffAddress.isNotEmpty;

  static ErrandPrivateDetails fromMap(Map<String, dynamic> data) {
    return ErrandPrivateDetails(
      pickupAddress: data['pickup_address'] ?? '',
      pickupLat: (data['pickup_lat'] as num?)?.toDouble() ?? 0,
      pickupLng: (data['pickup_lng'] as num?)?.toDouble() ?? 0,
      dropoffAddress: data['dropoff_address'] ?? '',
      dropoffLat: (data['dropoff_lat'] as num?)?.toDouble(),
      dropoffLng: (data['dropoff_lng'] as num?)?.toDouble(),
      shoppingList: (data['shopping_list'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      instructions: data['instructions'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pickup_address': pickupAddress,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dropoff_address': dropoffAddress,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
      'shopping_list': shoppingList,
      'instructions': instructions,
    };
  }

  @override
  List<Object?> get props => [
        pickupAddress,
        pickupLat,
        pickupLng,
        dropoffAddress,
        dropoffLat,
        dropoffLng,
        shoppingList,
        instructions,
      ];
}
