// lib/data/services/geohash_service.dart
import 'dart:math';


/// Service for encoding/decoding geohashes and performing bounding box calculations
/// for efficient Firestore location queries.
class GeohashService {
  /// Straight-line (haversine) distance between two points, in metres.
  /// Lives here rather than on a model so every feature that needs
  /// "how far away is this?" shares one implementation.
  static double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double r = 6371000;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;

  // Base32 character set for geohash encoding
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  // Neighbor lookup tables for precision 12
  static const Map<String, Map<String, String>> _neighbors = {
    'even': {
      'n': 'p0r21436x8zb9dcf5h7kjnmqesgutwvy',
      's': '14365h7k9dcfesgujnmqp0r2twvyx8zb',
      'e': 'bc01fg45238967deuvhjyznpkmstqrwx',
      'w': '238967debc01fg45kmstqrwxuvhjyznp',
    },
    'odd': {
      'n': 'bc01fg45238967deuvhjyznpkmstqrwx',
      's': '238967debc01fg45kmstqrwxuvhjyznp',
      'e': 'p0r21436x8zb9dcf5h7kjnmqesgutwvy',
      'w': '14365h7k9dcfesgujnmqp0r2twvyx8zb',
    },
  };

  /// Encode latitude and longitude to a geohash with specified precision
  /// Precision: 1-12 (higher = more accurate, longer string)
  ///
  /// BUG FIX: this previously packed each character's 5 bits in REVERSE
  /// order (`1 << bit`, least-significant first). Standard geohash puts
  /// the first bisection in the MOST significant bit (`1 << (4 - bit)`),
  /// which is what makes nearby places share prefixes and sort next to
  /// each other. With the bits reversed, equality still matched but
  /// geographic locality was destroyed, so the businesses range query
  /// (geohash >= SW corner AND <= NE corner) missed businesses even for
  /// someone standing at the exact same spot. decode() below was always
  /// correct (MSB-first), so encode and decode also disagreed with each
  /// other. Every geohash written before this fix is wrong and needs
  /// rewriting - see the migration note that shipped with this fix.
  String encode(double latitude, double longitude, {int precision = 12}) {
    if (precision < 1 || precision > 12) {
      throw ArgumentError('Precision must be between 1 and 12');
    }

    bool isEven = true;
    int bit = 0;
    int ch = 0;
    final StringBuffer geohash = StringBuffer();

    double minLat = -90.0;
    double maxLat = 90.0;
    double minLng = -180.0;
    double maxLng = 180.0;

    while (geohash.length < precision) {
      if (isEven) {
        // Longitude
        final double mid = (minLng + maxLng) / 2;
        if (longitude > mid) {
          ch |= (1 << (4 - bit));
          minLng = mid;
        } else {
          maxLng = mid;
        }
      } else {
        // Latitude
        final double mid = (minLat + maxLat) / 2;
        if (latitude > mid) {
          ch |= (1 << (4 - bit));
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }

      isEven = !isEven;

      if (bit < 4) {
        bit++;
      } else {
        geohash.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return geohash.toString();
  }

  /// Decode a geohash to latitude and longitude (center point and bounding box)
  (
    double lat,
    double lng,
    double minLat,
    double maxLat,
    double minLng,
    double maxLng,
  )
  decode(String geohash) {
    bool isEven = true;
    double minLat = -90.0;
    double maxLat = 90.0;
    double minLng = -180.0;
    double maxLng = 180.0;

    for (int i = 0; i < geohash.length; i++) {
      final int ch = _base32.indexOf(geohash[i]);
      if (ch == -1) {
        throw ArgumentError('Invalid geohash character: ${geohash[i]}');
      }

      for (int bit = 4; bit >= 0; bit--) {
        final int mask = 1 << bit;
        if (isEven) {
          // Longitude
          final double mid = (minLng + maxLng) / 2;
          if ((ch & mask) != 0) {
            minLng = mid;
          } else {
            maxLng = mid;
          }
        } else {
          // Latitude
          final double mid = (minLat + maxLat) / 2;
          if ((ch & mask) != 0) {
            minLat = mid;
          } else {
            maxLat = mid;
          }
        }
        isEven = !isEven;
      }
    }

    final double lat = (minLat + maxLat) / 2;
    final double lng = (minLng + maxLng) / 2;

    return (lat, lng, minLat, maxLat, minLng, maxLng);
  }

  /// Get neighboring geohashes in all 8 directions
  Map<String, String> getNeighbors(String geohash) {
    // final len = geohash.length;
    final Map<String, String> neighbors = {
      'n': _calculateAdjacent(geohash, 'n'),
      's': _calculateAdjacent(geohash, 's'),
      'e': _calculateAdjacent(geohash, 'e'),
      'w': _calculateAdjacent(geohash, 'w'),
      'ne': '',
      'nw': '',
      'se': '',
      'sw': '',
    };

    neighbors['ne'] = _calculateAdjacent(neighbors['n']!, 'e');
    neighbors['nw'] = _calculateAdjacent(neighbors['n']!, 'w');
    neighbors['se'] = _calculateAdjacent(neighbors['s']!, 'e');
    neighbors['sw'] = _calculateAdjacent(neighbors['s']!, 'w');

    return neighbors;
  }

  /// Calculate adjacent geohash in a specific direction
  String _calculateAdjacent(String geohash, String direction) {
    if (geohash.isEmpty) return '';

    final lastChar = geohash[geohash.length - 1];
    final parent = geohash.substring(0, geohash.length - 1);
    final type = (geohash.length % 2) == 0 ? 'even' : 'odd';

    final newLastChar =
        _neighbors[type]![direction]![_base32.indexOf(lastChar)];

    if (newLastChar.isEmpty) {
      return _calculateAdjacent(parent, direction) + _base32[0];
    }

    return parent + newLastChar;
  }

  /// Get a list of geohash prefixes for bounding box search
  /// This is used to query Firestore efficiently within a radius
  List<String> getBoundingBoxGeohashes(
    double latitude,
    double longitude,
    double radiusKm, {
    int precision = 8,
  }) {
    // Convert radius to degrees (approximate)
    final double latDelta = radiusKm / 111.0; // 1 degree latitude ≈ 111 km
    final double lngDelta = radiusKm / (111.0 * cos(latitude * pi / 180.0));

    // Calculate bounding box
    final double minLat = latitude - latDelta;
    final double maxLat = latitude + latDelta;
    final double minLng = longitude - lngDelta;
    final double maxLng = longitude + lngDelta;

    // Find min/max geohashes in the bounding box
    // final centerGeohash = encode(latitude, longitude, precision: precision);
    final minGeohash = encode(minLat, minLng, precision: precision);
    final maxGeohash = encode(maxLat, maxLng, precision: precision);

    // Expand to get all geohashes in the bounding box
    final Set<String> geohashes = {};

    // Start from min and scan to max
    String current = minGeohash;
    while (current.compareTo(maxGeohash) <= 0) {
      geohashes.add(current);
      current = _incrementGeohash(current);
    }

    return geohashes.toList();
  }

  /// Increment a geohash string (for bounding box iteration)
  String _incrementGeohash(String geohash) {
    final chars = geohash.split('');
    for (int i = chars.length - 1; i >= 0; i--) {
      final int idx = _base32.indexOf(chars[i]);
      if (idx < _base32.length - 1) {
        chars[i] = _base32[idx + 1];
        return chars.join();
      } else {
        chars[i] = _base32[0];
      }
    }
    return geohash;
  }

  /// Get geohash with reduced precision (parent geohash)
  String getParent(String geohash, {int levels = 1}) {
    if (levels <= 0) return geohash;
    if (geohash.length <= levels) return geohash[0];
    return getParent(
      geohash.substring(0, geohash.length - 1),
      levels: levels - 1,
    );
  }

  /// Check if a geohash is within a bounding box of another geohash
  bool isWithinRadius(
    String geohash1,
    String geohash2,
    double radiusKm, {
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    final distance = distanceMeters(lat1, lng1, lat2, lng2);
    return distance <= radiusKm * 1000;
  }

  /// Generate geohashes covering a circular area, e.g. a runner's
  /// working radius
  List<String> generateServiceAreaGeohashes(
    double centerLat,
    double centerLng,
    double radiusKm, {
    int precision = 7,
  }) {
    final geohashes = <String>{};

    // Calculate number of steps (roughly 1 step per 10km for precision 7)
    final steps = (radiusKm / 10).ceil();
    final double stepLat = radiusKm / steps / 111.0;
    final double stepLng =
        radiusKm / steps / (111.0 * cos(centerLat * pi / 180));

    for (int i = -steps; i <= steps; i++) {
      for (int j = -steps; j <= steps; j++) {
        final lat = centerLat + (i * stepLat);
        final lng = centerLng + (j * stepLng);

        // Check if point is within radius
        if (distanceMeters(centerLat, centerLng, lat, lng) <=
            radiusKm * 1000) {
          geohashes.add(encode(lat, lng, precision: precision));
        }
      }
    }

    return geohashes.toList();
  }

  /// Get the bounding box as a Firestore query filter
  /// Returns min and max geohashes for range query
  (String min, String max) getBoundingBoxRange(
    double latitude,
    double longitude,
    double radiusKm, {
    int precision = 8,
  }) {
    final double latDelta = radiusKm / 111.0;
    final double lngDelta = radiusKm / (111.0 * cos(latitude * pi / 180));

    final double minLat = latitude - latDelta;
    final double minLng = longitude - lngDelta;
    final double maxLat = latitude + latDelta;
    final double maxLng = longitude + lngDelta;

    final String minGeohash = encode(minLat, minLng, precision: precision);
    final String maxGeohash = encode(maxLat, maxLng, precision: precision);

    return (minGeohash, maxGeohash);
  }

  /// Calculate the optimal geohash precision for a given radius
  int getOptimalPrecision(double radiusKm) {
    if (radiusKm <= 0.6) return 8; // ~600m
    if (radiusKm <= 2.4) return 7; // ~2.4km
    if (radiusKm <= 20) return 6; // ~20km
    if (radiusKm <= 78) return 5; // ~78km
    if (radiusKm <= 630) return 4; // ~630km
    return 3; // ~2500km
  }

  /// Estimate distance between two geohashes (approximate)
  double estimateDistanceBetweenGeohashes(String geohash1, String geohash2) {
    final (lat1, lng1, _, _, _, _) = decode(geohash1);
    final (lat2, lng2, _, _, _, _) = decode(geohash2);
    return distanceMeters(lat1, lng1, lat2, lng2);
  }

  /// The 3x3 block of geohash cells around a point, each cell at least
  /// [radiusKm] tall, so every point within [radiusKm] falls inside one
  /// of them. Query each cell as a prefix range:
  ///   where(field, >= cell).where(field, <= '$cell~')
  /// This is how location searches stay correct as the app grows: the
  /// database only returns things in these cells, instead of "the
  /// latest 50 in the country" filtered on the phone.
  List<String> coveringCells(double lat, double lng, double radiusKm) {
    // Smallest cell side for each precision (km): 5 -> 4.9, 4 -> 19.5,
    // 3 -> 156, 2 -> 625.
    final int precision;
    if (radiusKm <= 4.8) {
      precision = 5;
    } else if (radiusKm <= 19.5) {
      precision = 4;
    } else if (radiusKm <= 156) {
      precision = 3;
    } else {
      precision = 2;
    }
    // Cell size in degrees for this precision (5 bits per character,
    // longitude takes the extra bit when the total is odd).
    final bits = precision * 5;
    final cellLat = 180 / pow(2, bits ~/ 2);
    final cellLng = 360 / pow(2, (bits + 1) ~/ 2);
    // Middle of the cell the point is in, then step one whole cell in
    // each direction. (Worked out from coordinates rather than the
    // character-table neighbour lookup, which returned wrong cells -
    // caught by test/geohash_cells_test.dart.)
    final midLat = ((lat + 90) / cellLat).floor() * cellLat - 90 + cellLat / 2;
    final midLng = ((lng + 180) / cellLng).floor() * cellLng - 180 + cellLng / 2;
    final cells = <String>{};
    for (final dLat in const [-1, 0, 1]) {
      for (final dLng in const [-1, 0, 1]) {
        final cLat = (midLat + dLat * cellLat).clamp(-89.999999, 89.999999);
        var cLng = midLng + dLng * cellLng;
        if (cLng > 180) cLng -= 360;
        if (cLng < -180) cLng += 360;
        cells.add(encode(cLat.toDouble(), cLng, precision: precision));
      }
    }
    return cells.toList();
  }
}
