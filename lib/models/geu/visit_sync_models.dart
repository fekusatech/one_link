import 'dart:convert';

enum VisitSyncAction { checkin, checkout }

enum VisitSyncState { pending, retrying, succeeded, conflict }

/// A durable, ordered write for the Visit Planner API. The [id] is also the
/// Idempotency-Key sent to the server, so retried requests never become a new
/// visit when the server supports idempotency.
class VisitSyncItem {
  final String id;
  final VisitSyncAction action;
  final Map<String, dynamic> payload;
  final String? dependsOnId;
  final DateTime createdAt;
  final DateTime nextAttemptAt;
  final int attempts;
  final VisitSyncState state;
  final String? lastError;

  const VisitSyncItem({
    required this.id,
    required this.action,
    required this.payload,
    required this.createdAt,
    required this.nextAttemptAt,
    this.dependsOnId,
    this.attempts = 0,
    this.state = VisitSyncState.pending,
    this.lastError,
  });

  String get endpoint => action == VisitSyncAction.checkin
      ? '/api/visits/checkin'
      : '/api/visits/checkout';

  VisitSyncItem copyWith({
    DateTime? nextAttemptAt,
    int? attempts,
    VisitSyncState? state,
    String? lastError,
  }) =>
      VisitSyncItem(
        id: id,
        action: action,
        payload: payload,
        dependsOnId: dependsOnId,
        createdAt: createdAt,
        nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
        attempts: attempts ?? this.attempts,
        state: state ?? this.state,
        lastError: lastError,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'action': action.name,
        'payload': payload,
        'depends_on_id': dependsOnId,
        'created_at': createdAt.toIso8601String(),
        'next_attempt_at': nextAttemptAt.toIso8601String(),
        'attempts': attempts,
        'state': state.name,
        'last_error': lastError,
      };

  factory VisitSyncItem.fromJson(Map<String, dynamic> json) => VisitSyncItem(
        id: json['id'] as String,
        action: VisitSyncAction.values.byName(json['action'] as String),
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        dependsOnId: json['depends_on_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        nextAttemptAt: DateTime.parse(json['next_attempt_at'] as String),
        attempts: json['attempts'] as int? ?? 0,
        state: VisitSyncState.values.byName(
          json['state'] as String? ?? VisitSyncState.pending.name,
        ),
        lastError: json['last_error'] as String?,
      );

  static List<VisitSyncItem> decodeList(String raw) => (jsonDecode(raw) as List)
      .map((item) => VisitSyncItem.fromJson(Map<String, dynamic>.from(item as Map)))
      .toList();

  static String encodeList(List<VisitSyncItem> items) =>
      jsonEncode(items.map((item) => item.toJson()).toList());
}
