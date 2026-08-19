import 'dart:math';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/geu/visit_sync_models.dart';
import 'geu_api_client.dart';

/// Queue-first delivery for critical Visit Planner writes.
///
/// Queue metadata is encrypted with the platform keystore. Photos are kept
/// out of this JSON queue: the photo task stores their local file separately
/// and only its path will be queued, avoiding secure-storage size limits.
class VisitSyncService {
  static const _storageKey = 'geu_visit_sync_queue_v1';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static bool _isSyncing = false;

  static const _backoff = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 60),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 60),
  ];

  static Future<VisitSyncItem> enqueueCheckin({
    required int supplierId,
    required double latitude,
    required double longitude,
    String address = '',
    required String photoPath,
    double? gpsAccuracyMeters,
    bool? isMockLocation,
  }) => _enqueue(VisitSyncAction.checkin, {
    'supplier_id': supplierId,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'photo_path': photoPath,
    if (gpsAccuracyMeters != null) 'gps_accuracy_m': gpsAccuracyMeters,
    if (isMockLocation != null) 'is_mock_location': isMockLocation,
  });

  static Future<VisitSyncItem> enqueueCheckout({
    required double latitude,
    required double longitude,
    String address = '',
    String notes = '',
    required String photoPath,
    List<int> workOrderIds = const [],
    double? gpsAccuracyMeters,
    bool? isMockLocation,
  }) => _enqueueCheckout(
    latitude: latitude,
    longitude: longitude,
    address: address,
    notes: notes,
    photoPath: photoPath,
    workOrderIds: workOrderIds,
    gpsAccuracyMeters: gpsAccuracyMeters,
    isMockLocation: isMockLocation,
  );

  static Future<VisitSyncItem> _enqueueCheckout({
    required double latitude,
    required double longitude,
    required String address,
    required String notes,
    required String photoPath,
    required List<int> workOrderIds,
    double? gpsAccuracyMeters,
    bool? isMockLocation,
  }) async {
    final queue = await _read();
    final dependency = queue
        .where(
          (item) =>
              item.action == VisitSyncAction.checkin &&
              item.state != VisitSyncState.succeeded,
        )
        .firstOrNull;
    return _enqueue(VisitSyncAction.checkout, {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'notes': notes,
      'photo_path': photoPath,
      'work_order_ids': workOrderIds,
      if (gpsAccuracyMeters != null) 'gps_accuracy_m': gpsAccuracyMeters,
      if (isMockLocation != null) 'is_mock_location': isMockLocation,
    }, dependsOnId: dependency?.id);
  }

  static Future<List<VisitSyncItem>> pendingItems() async => (await _read())
      .where((item) => item.state != VisitSyncState.succeeded)
      .toList();

  static Future<List<VisitSyncItem>> allItems() => _read();

  /// Removes only unsent visit data after an explicit destructive logout.
  static Future<void> discardPending() async {
    final queue = await _read();
    for (final item in queue.where(
      (item) => item.state != VisitSyncState.succeeded,
    )) {
      await _deletePhoto(item);
    }
    await _write(
      queue.where((item) => item.state == VisitSyncState.succeeded).toList(),
    );
  }

  static Future<void> retryConflict(String id) async {
    final queue = await _read();
    await _write(
      queue
          .map(
            (item) => item.id == id
                ? item.copyWith(
                    state: VisitSyncState.pending,
                    nextAttemptAt: DateTime.now(),
                  )
                : item,
          )
          .toList(),
    );
    await syncNow();
  }

  /// Delivers at most one item at a time. Call again after a success to drain
  /// the queue, or from connectivity/startup hooks to resume pending writes.
  static Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      while (true) {
        final queue = await _read();
        final next = _nextRunnable(queue);
        if (next == null) return;
        final result = await _deliver(next);
        final updated = queue
            .map((item) => item.id == next.id ? result : item)
            .toList();
        await _write(updated);
        if (result.state != VisitSyncState.succeeded) return;
      }
    } finally {
      _isSyncing = false;
    }
  }

  static VisitSyncItem? _nextRunnable(List<VisitSyncItem> queue) {
    final now = DateTime.now();
    for (final item in queue) {
      if (item.state != VisitSyncState.pending &&
          item.state != VisitSyncState.retrying) {
        continue;
      }
      if (item.nextAttemptAt.isAfter(now)) continue;
      if (item.dependsOnId != null) {
        final parent = queue
            .where((entry) => entry.id == item.dependsOnId)
            .firstOrNull;
        if (parent == null || parent.state != VisitSyncState.succeeded)
          continue;
      }
      return item;
    }
    return null;
  }

  static Future<VisitSyncItem> _deliver(VisitSyncItem item) async {
    try {
      final dio = await GeuApiClient.instance;
      final response = await dio.post(
        item.endpoint,
        data: await _requestPayload(item),
        options: Options(headers: {'Idempotency-Key': item.id}),
      );
      final status = response.statusCode ?? 0;
      if ((status >= 200 && status < 300) || status == 409) {
        await _deletePhoto(item);
        return item.copyWith(state: VisitSyncState.succeeded, lastError: null);
      }
      if (status >= 400 && status < 500) {
        return item.copyWith(
          state: VisitSyncState.conflict,
          lastError: _message(response),
        );
      }
      return _retry(item, _message(response));
    } on FileSystemException catch (error) {
      return item.copyWith(
        state: VisitSyncState.conflict,
        lastError: error.message,
      );
    } catch (error) {
      return _retry(item, error.toString());
    }
  }

  static VisitSyncItem _retry(VisitSyncItem item, String error) {
    final attempts = item.attempts + 1;
    final delay = retryDelayForAttempt(attempts);
    return item.copyWith(
      state: VisitSyncState.retrying,
      attempts: attempts,
      nextAttemptAt: DateTime.now().add(delay),
      lastError: error,
    );
  }

  static Duration retryDelayForAttempt(int attempts) =>
      _backoff[min(max(attempts, 1) - 1, _backoff.length - 1)];

  static String _message(Response<dynamic> response) {
    final data = response.data;
    if (data is Map && data['message'] is String)
      return data['message'] as String;
    return 'Sinkronisasi gagal (HTTP ${response.statusCode ?? 0}).';
  }

  static Future<Map<String, dynamic>> _requestPayload(
    VisitSyncItem item,
  ) async {
    final payload = Map<String, dynamic>.from(item.payload);
    final photoPath = payload.remove('photo_path') as String?;
    if (photoPath != null && photoPath.isNotEmpty) {
      final photo = File(photoPath);
      if (!await photo.exists()) {
        throw FileSystemException(
          'Foto check-in antrean tidak ditemukan.',
          photoPath,
        );
      }
      payload['photo_base64'] = base64Encode(await photo.readAsBytes());
    }
    return payload;
  }

  static Future<void> _deletePhoto(VisitSyncItem item) async {
    final photoPath = item.payload['photo_path'] as String?;
    if (photoPath == null || photoPath.isEmpty) return;
    final photo = File(photoPath);
    if (await photo.exists()) await photo.delete();
  }

  static Future<VisitSyncItem> _enqueue(
    VisitSyncAction action,
    Map<String, dynamic> payload, {
    String? dependsOnId,
  }) async {
    final now = DateTime.now();
    final item = VisitSyncItem(
      id: '${now.microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
      action: action,
      payload: payload,
      dependsOnId: dependsOnId,
      createdAt: now,
      nextAttemptAt: now,
    );
    final queue = await _read();
    queue.add(item);
    await _write(queue);
    return item;
  }

  static Future<List<VisitSyncItem>> _read() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return [];
    return VisitSyncItem.decodeList(raw);
  }

  static Future<void> _write(List<VisitSyncItem> queue) =>
      _storage.write(key: _storageKey, value: VisitSyncItem.encodeList(queue));
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
