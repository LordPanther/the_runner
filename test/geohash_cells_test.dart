import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_runner/data/services/geohash_service.dart';

void main() {
  final geohash = GeohashService();

  // Every point within the radius must land in one of the 3x3 cells,
  // otherwise nearby results would silently go missing.
  for (final radiusKm in [2.0, 10.0, 19.5, 50.0]) {
    test('cells around Durban cover everything within ${radiusKm}km', () {
      const lat = -29.8587, lng = 31.0218;
      final cells = geohash.coveringCells(lat, lng, radiusKm);
      expect(cells.length, 9);

      final random = Random(42);
      for (var i = 0; i < 500; i++) {
        final distanceKm = random.nextDouble() * radiusKm;
        final bearing = random.nextDouble() * 2 * pi;
        final pLat = lat + (distanceKm / 111.0) * cos(bearing);
        final pLng = lng + (distanceKm / (111.0 * cos(lat * pi / 180))) * sin(bearing);
        final hash = geohash.encode(pLat, pLng);
        expect(cells.any(hash.startsWith), isTrue,
            reason: 'point $distanceKm km away ($hash) not in $cells');
      }
    });
  }
}
