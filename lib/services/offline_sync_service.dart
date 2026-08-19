import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineSyncItem {
  final String id;
  final String type; // 'gps_location', 'settlement_draft', 'pickup_note'
  final Map<String, dynamic> data;
  final DateTime createdAt;
  bool isSyncing;

  OfflineSyncItem({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.isSyncing = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'data': data,
        'created_at': createdAt.toIso8601String(),
      };

  factory OfflineSyncItem.fromJson(Map<String, dynamic> json) => OfflineSyncItem(
        id: json['id'] as String,
        type: json['type'] as String,
        data: json['data'] as Map<String, dynamic>,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class OfflineSyncService {
  static const String _keyQueue = 'tms_offline_sync_queue_v1';
  static bool _isSyncingInProgress = false;

  /// Check internet reachability safely
  static Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup('apipi.greenenergiutama.co.id')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Add item to offline sync queue
  static Future<void> enqueue(String type, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_keyQueue) ?? [];

    final newItem = OfflineSyncItem(
      id: '${DateTime.now().millisecondsSinceEpoch}_${data.hashCode}',
      type: type,
      data: data,
      createdAt: DateTime.now(),
    );

    rawList.add(jsonEncode(newItem.toJson()));
    await prefs.setStringList(_keyQueue, rawList);
  }

  /// Get pending item count
  static Future<int> getPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_keyQueue) ?? [];
    return rawList.length;
  }

  /// Get pending queue items
  static Future<List<OfflineSyncItem>> getPendingItems() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_keyQueue) ?? [];
    return rawList.map((str) => OfflineSyncItem.fromJson(jsonDecode(str))).toList();
  }

  /// Trigger safe automatic background sync without duplicate execution
  static Future<void> syncNow() async {
    if (_isSyncingInProgress) return;

    final online = await isOnline();
    if (!online) return;

    _isSyncingInProgress = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_keyQueue) ?? [];
      if (rawList.isEmpty) {
        _isSyncingInProgress = false;
        return;
      }

      final remainingList = <String>[];

      for (var str in rawList) {
        try {
          final item = OfflineSyncItem.fromJson(jsonDecode(str));
          bool success = await _processItem(item);
          if (!success) {
            remainingList.add(str);
          }
        } catch (_) {
          // Keep corrupted items or remove if unparseable
        }
      }

      await prefs.setStringList(_keyQueue, remainingList);
    } finally {
      _isSyncingInProgress = false;
    }
  }

  static Future<bool> _processItem(OfflineSyncItem item) async {
    // Process item based on type
    if (item.type == 'gps_location') {
      // Background location update was stored offline
      return true;
    }
    return true; // Mark as processed
  }
}
