import 'package:flutter/foundation.dart';

import '../../models/geu/visit_sync_models.dart';
import 'geu_api_client.dart';
import 'visit_sync_service.dart';

class ActiveVisitState {
  final bool isActive;
  final bool isPendingLocal;
  final bool syncFailed;
  final int? supplierId;
  final String? supplierName;
  const ActiveVisitState({
    required this.isActive,
    this.isPendingLocal = false,
    this.syncFailed = false,
    this.supplierId,
    this.supplierName,
  });
}

/// Restores visit state after a restart. A local unsynced check-in wins over
/// the server response, preventing a user from losing an offline check-in.
class ActiveVisitService {
  static final ValueNotifier<ActiveVisitState> current = ValueNotifier(
    const ActiveVisitState(isActive: false),
  );

  static Future<ActiveVisitState> restore() async {
    final local = await VisitSyncService.pendingItems();
    final queued = local
        .where((item) => item.action == VisitSyncAction.checkin)
        .firstOrNull;
    if (queued != null) {
      return _set(
        ActiveVisitState(
          isActive: true,
          isPendingLocal: true,
          supplierId: queued.payload['supplier_id'] as int?,
        ),
      );
    }
    try {
      final dio = await GeuApiClient.instance;
      final response = await dio.get('/api/visits/status');
      final body = response.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? body;
      final active = data['has_active_checkin'] == true;
      final visit = data['visit'] as Map<String, dynamic>?;
      return _set(
        ActiveVisitState(
          isActive: active,
          supplierId: visit?['supplier_id'] as int?,
          supplierName: visit?['supplier_name'] as String?,
        ),
      );
    } catch (_) {
      return _set(const ActiveVisitState(isActive: false));
    }
  }

  static ActiveVisitState _set(ActiveVisitState state) {
    current.value = state;
    return state;
  }

  static void markPendingCheckin(int supplierId) => _set(
    ActiveVisitState(
      isActive: true,
      isPendingLocal: true,
      supplierId: supplierId,
    ),
  );

  /// Only call once the checkout is CONFIRMED delivered
  /// (`VisitSyncService.wasDelivered`) — clearing this optimistically before
  /// delivery is exactly how a stuck check-in goes unnoticed on-device: the
  /// server still sees the visit as open and will reject the next check-in
  /// with 409, but the app itself no longer suspects anything is wrong.
  static void markCheckoutQueued() =>
      _set(const ActiveVisitState(isActive: false));

  /// The checkout request reached the server and was hard-rejected (e.g. GPS
  /// too far from the check-in point) or is still stuck retrying — the
  /// server-side visit is still open. Keep isActive so the RO sees a warning
  /// instead of the app silently forgetting about it until the next blocked
  /// check-in confuses them.
  static void markCheckoutFailed({
    required int supplierId,
    required String supplierName,
  }) => _set(
    ActiveVisitState(
      isActive: true,
      syncFailed: true,
      supplierId: supplierId,
      supplierName: supplierName,
    ),
  );
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
