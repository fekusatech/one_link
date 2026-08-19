import 'package:flutter/foundation.dart';
import '../../models/geu/visit_planner_models.dart';

/// Keeps the active in-app Mission visible while the user moves between the
/// Visit Plan and CRO dashboard. It is intentionally in-memory: ending a
/// Mission or closing the app returns the map to its normal planning state.
class MissionNavigationState {
  const MissionNavigationState({
    this.isActive = false,
    this.destination,
    this.destinationSupplierId,
    this.totalVisits = 0,
    this.completedVisits = 0,
  });

  final bool isActive;
  final String? destination;
  final int? destinationSupplierId;
  final int totalVisits;
  final int completedVisits;

  int get remainingVisits =>
      (totalVisits - completedVisits).clamp(0, totalVisits);
}

class MissionNavigationStateService {
  MissionNavigationStateService._();

  static final ValueNotifier<MissionNavigationState> current = ValueNotifier(
    const MissionNavigationState(),
  );

  static void start({
    required MissionItem destination,
    required List<MissionItem> items,
  }) {
    current.value = _fromItems(
      items: items,
      destination: destination,
      isActive: true,
    );
  }

  static void refresh(List<MissionItem> items) {
    final value = current.value;
    if (!value.isActive) return;
    final destination = items.cast<MissionItem?>().firstWhere(
      (item) => item?.supplierId == value.destinationSupplierId,
      orElse: () => null,
    );
    current.value = _fromItems(
      items: items,
      destination: destination,
      isActive: true,
    );
  }

  static void end() => current.value = const MissionNavigationState();

  static MissionNavigationState _fromItems({
    required List<MissionItem> items,
    required MissionItem? destination,
    required bool isActive,
  }) {
    final completed = items
        .where((item) => item.status.toUpperCase() == 'VISITED')
        .length;
    return MissionNavigationState(
      isActive: isActive,
      destination: destination?.supplierName,
      destinationSupplierId: destination?.supplierId,
      totalVisits: items.length,
      completedVisits: completed,
    );
  }
}
