// lib/data/services/address_search_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:the_runner/configs/api_keys.dart';

/// A real, findable place picked from search results. Errands only
/// accept addresses chosen from these, so a runner can always navigate
/// to them.
class AddressSuggestion {
  /// Full address as shown to people, e.g. "12 Musgrave Road, Berea, Durban".
  final String label;
  final double lat;
  final double lng;

  /// Suburb or neighbourhood, used to pre-fill the errand's area label.
  final String? suburb;

  const AddressSuggestion({
    required this.label,
    required this.lat,
    required this.lng,
    this.suburb,
  });
}

/// Address search-as-you-type and "what's at this spot?", backed by
/// MapTiler's geocoding API (same key as the map, no Google billing).
///
/// NOTE: everything address-related goes through this one class. If
/// coverage turns out too thin in some areas, swap the two methods for
/// Google Places Autocomplete and nothing else in the app changes.
class AddressSearchService {
  static const _host = 'api.maptiler.com';
  static const _timeout = Duration(seconds: 8);

  /// Suggestions for what the person has typed so far, limited to South
  /// Africa and biased towards [nearLat]/[nearLng] when known.
  static Future<List<AddressSuggestion>> search(
    String query, {
    double? nearLat,
    double? nearLng,
  }) async {
    final text = query.trim();
    if (text.length < 3) return const [];
    return _get(
      '/geocoding/${Uri.encodeComponent(text)}.json',
      {
        'country': 'za',
        'autocomplete': 'true',
        'limit': '6',
        'language': 'en',
        if (nearLat != null && nearLng != null) 'proximity': '$nearLng,$nearLat',
      },
    );
  }

  /// The address at a point, for "Use my current location".
  static Future<AddressSuggestion?> reverse(double lat, double lng) async {
    final results = await _get('/geocoding/$lng,$lat.json', {'limit': '1', 'language': 'en'});
    if (results.isEmpty) return null;
    // Keep the exact GPS point, not the centre of the matched address.
    final first = results.first;
    return AddressSuggestion(label: first.label, lat: lat, lng: lng, suburb: first.suburb);
  }

  static Future<List<AddressSuggestion>> _get(
    String path,
    Map<String, String> params,
  ) async {
    final uri = Uri.https(_host, path, {...params, 'key': ApiKeys.mapTiler});
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(uri).timeout(_timeout);
      final response = await request.close().timeout(_timeout);
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        debugPrint('Address search failed (${response.statusCode}): $body');
        throw Exception('Address search unavailable');
      }
      final features = (jsonDecode(body)['features'] as List<dynamic>? ?? const []);
      return features
          .map((f) => _fromFeature(f as Map<String, dynamic>))
          .whereType<AddressSuggestion>()
          .toList();
    } finally {
      client.close();
    }
  }

  static AddressSuggestion? _fromFeature(Map<String, dynamic> feature) {
    final center = feature['center'] as List<dynamic>?;
    final label = feature['place_name'] as String?;
    if (center == null || center.length < 2 || label == null) return null;

    // `context` lists the areas this place sits inside, smallest first
    // (e.g. neighbourhood, then municipality, then province).
    String? suburb;
    for (final c in (feature['context'] as List<dynamic>? ?? const [])) {
      final id = (c as Map<String, dynamic>)['id'] as String? ?? '';
      if (id.startsWith('neighbourhood') ||
          id.startsWith('locality') ||
          id.startsWith('place')) {
        suburb = c['text'] as String?;
        break;
      }
    }

    return AddressSuggestion(
      label: label,
      lat: (center[1] as num).toDouble(),
      lng: (center[0] as num).toDouble(),
      suburb: suburb,
    );
  }

  AddressSearchService._();
}
