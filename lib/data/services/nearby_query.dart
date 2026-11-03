// lib/data/services/nearby_query.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:the_runner/data/services/geohash_service.dart';

/// Default distance a runner sees errands within. Errands are local by
/// nature (a runner travels to the pickup), so this is deliberately
/// tighter than a directory search would be.
const double kErrandSearchRadiusKm = 10;

/// Runs [base] once per geohash cell around (lat, lng) and merges the
/// results (no duplicates). [field] is the document's geohash field,
/// e.g. 'geohash' or 'base_geohash'. The caller still checks the exact
/// distance; this only narrows down WHERE to look, so results stay
/// correct no matter how many records exist across the country.
Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> queryNearby({
  required Query<Map<String, dynamic>> base,
  required String field,
  required double lat,
  required double lng,
  required double radiusKm,
  int perCell = 100,
}) async {
  final cells = GeohashService().coveringCells(lat, lng, radiusKm);
  final snapshots = await Future.wait(cells.map((cell) => base
      .where(field, isGreaterThanOrEqualTo: cell)
      .where(field, isLessThanOrEqualTo: '$cell~')
      .limit(perCell)
      .get()));
  final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
  for (final snapshot in snapshots) {
    for (final doc in snapshot.docs) {
      byId[doc.id] = doc;
    }
  }
  return byId.values.toList();
}
