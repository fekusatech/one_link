import 'package:flutter_test/flutter_test.dart';
import 'package:one_link/models/geu/visit_sync_models.dart';
import 'package:one_link/services/geu/visit_sync_service.dart';

void main() {
  test('queue item serializes its dependency and stable id', () {
    final item = VisitSyncItem(
      id: 'stable-key',
      action: VisitSyncAction.checkout,
      payload: {'latitude': -6.2, 'work_order_ids': [12]},
      dependsOnId: 'checkin-key',
      createdAt: DateTime.utc(2026, 8, 13),
      nextAttemptAt: DateTime.utc(2026, 8, 13),
    );

    final decoded = VisitSyncItem.decodeList(VisitSyncItem.encodeList([item])).single;

    expect(decoded.id, 'stable-key');
    expect(decoded.dependsOnId, 'checkin-key');
    expect(decoded.endpoint, '/api/visits/checkout');
  });

  test('retry backoff caps at one hour', () {
    expect(VisitSyncService.retryDelayForAttempt(1), const Duration(seconds: 5));
    expect(VisitSyncService.retryDelayForAttempt(4), const Duration(minutes: 5));
    expect(VisitSyncService.retryDelayForAttempt(99), const Duration(minutes: 60));
  });
}
