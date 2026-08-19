import 'package:flutter/foundation.dart';

import '../../models/geu/visit_sync_models.dart';
import 'geu_api_client.dart';
import 'visit_sync_service.dart';

class ActiveVisitState {
  final bool isActive;
  final bool isPendingLocal;
  final int? supplierId;
  const ActiveVisitState({
    required this.isActive,
    this.isPendingLocal = false,
    this.supplierId,
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
  static void markCheckoutQueued() =>
      _set(const ActiveVisitState(isActive: false));
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
