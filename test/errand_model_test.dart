import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_runner/data/models/errand_model.dart';

void main() {
  final created = DateTime(2026, 11, 4, 9);

  Map<String, dynamic> raw(Map<String, dynamic> overrides) => {
        'requester_uid': 'req1',
        'type': 'shopping',
        'title': 'Groceries from Musgrave',
        'description': '',
        'area_label': 'Berea',
        'lat': -29.85,
        'lng': 31.0,
        'geohash': 'ke7',
        'bidding_closes_at': Timestamp.fromDate(created.add(const Duration(hours: 2))),
        'starting_fee': 60,
        'fee_cap': 100,
        'requester_fee_rate': 0.05,
        'runner_fee_rate': 0.05,
        'purchase_budget': 500,
        'status': 'bidding',
        'created_at': Timestamp.fromDate(created),
        ...overrides,
      };

  test('reads snake_case wire values', () {
    final errand = ErrandModel.fromMap(raw({'status': 'proof_submitted'}), 'e1');
    expect(errand.id, 'e1');
    expect(errand.type, ErrandType.shopping);
    expect(errand.status, ErrandStatus.proofSubmitted);
    expect(errand.status.isFundsHeld, isTrue);
    expect(errand.purchaseBudget, 500);
  });

  test('every status round-trips through its wire value', () {
    for (final status in ErrandStatus.values) {
      expect(ErrandStatus.fromWire(status.wire), status);
    }
  });

  test('unknown values fall back safely instead of crashing', () {
    final errand = ErrandModel.fromMap(raw({'status': 'nonsense', 'type': 'nope'}), 'e2');
    expect(errand.status, ErrandStatus.draft);
    expect(errand.type, ErrandType.pickupDropoff);
  });

  test('requester total once a bid is agreed', () {
    final errand = ErrandModel.fromMap(raw({'agreed_fee': 80, 'status': 'accepted'}), 'e3');
    // R80 + R4 service fee + R500 budget
    expect(errand.requesterTotal, 584);
    expect(errand.runnerPayoutFor(80), 76);
  });

  test('expired with no bids can be edited and relisted', () {
    final expired = ErrandModel.fromMap(raw({'status': 'cancelled', 'cancelled_by': 'system'}), 'e5');
    expect(expired.isExpiredUnbid, isTrue);
    expect(expired.canEditAndRelist, isTrue);

    final cancelledByUser = ErrandModel.fromMap(raw({'status': 'cancelled', 'cancelled_by': 'req1'}), 'e6');
    expect(cancelledByUser.canEditAndRelist, isFalse);

    final openNoBids = ErrandModel.fromMap(raw({'bid_count': 0}), 'e7');
    expect(openNoBids.canEditAndRelist, isTrue);

    final openWithBids = ErrandModel.fromMap(raw({'bid_count': 2}), 'e8');
    expect(openWithBids.canEditAndRelist, isFalse);
  });
}
