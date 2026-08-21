import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/geu/visit_planner_models.dart';
import 'geu_api_client.dart';

class VisitPlannerException implements Exception {
  final String message;
  VisitPlannerException(this.message);
  @override
  String toString() => message;
}

/// GET /api/visit-planner/mission/today + friends (go-rest-api). Read-cached
/// to shared_preferences per PRD A1 — served stale with a timestamp when
/// offline, refreshed opportunistically when online.
class VisitPlannerService {
  static const _cacheKey = 'geu_mission_today_cache';
  static const _cacheAtKey = 'geu_mission_today_cache_at';
  static const _historyCacheKey = 'geu_visit_history_cache';
  static const _historyCacheAtKey = 'geu_visit_history_cache_at';

  static Future<VisitHistoryPage> getVisitHistory({
    required DateTime from,
    required DateTime until,
    int page = 1,
  }) async {
    try {
      final dio = await GeuApiClient.instance;
      final response = await dio.get(
        '/api/visits/history',
        queryParameters: {
          'date_from': _date(from),
          'date_to': _date(until),
          'page': page,
          'limit': 20,
        },
      );
      final body = response.data;
      final data = body is Map<String, dynamic> && body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : Map<String, dynamic>.from(body as Map);
      if (response.statusCode != 200 ||
          (body is Map && body['status'] == 'error')) {
        throw VisitPlannerException(
          (body is Map ? body['message'] : null)?.toString() ??
              'Riwayat kunjungan tidak dapat dimuat.',
        );
      }
      final result = VisitHistoryPage.fromJson(data);
      if (page == 1) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_historyCacheKey, jsonEncode(result.toJson()));
        await prefs.setInt(
          _historyCacheAtKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      }
      return result;
    } catch (_) {
      if (page != 1) rethrow;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyCacheKey);
      if (raw == null) rethrow;
      final cached = VisitHistoryPage.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      final at = prefs.getInt(_historyCacheAtKey);
      return cached.withCachedAt(DateTime.fromMillisecondsSinceEpoch(at ?? 0));
    }
  }

  static Future<TodaysMission> getTodaysMission({
    bool forceRefresh = false,
  }) async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.get('/api/visit-planner/mission/today');
      final body = res.data as Map<String, dynamic>;
      if (body['status'] != 'success') {
        throw VisitPlannerException(
          body['message'] ?? 'Gagal memuat mission hari ini',
        );
      }
      final mission = TodaysMission.fromJson(
        body['data'] as Map<String, dynamic>,
      );
      await _saveCache(mission);
      return mission;
    } catch (e) {
      if (e is VisitPlannerException) rethrow;
      final cached = await _loadCache();
      if (cached != null) return cached;
      throw VisitPlannerException(
        'Tidak ada koneksi dan belum ada data tersimpan.',
      );
    }
  }

  static Future<void> _saveCache(TodaysMission mission) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(mission.toJson()));
    await prefs.setInt(_cacheAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<TodaysMission?> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    final cachedAtMs = prefs.getInt(_cacheAtKey);
    final mission = TodaysMission.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    return mission.withCachedAt(
      cachedAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(cachedAtMs)
          : DateTime.now(),
    );
  }

  static Future<List<WorkOrderStatus>> getWorkOrderStatuses() async {
    final dio = await GeuApiClient.instance;
    final response = await dio.get('/api/visit-planner/wo-statuses');
    final body = response.data;
    final data = body is Map && body['data'] is List ? body['data'] : body;
    if (response.statusCode != 200 || data is! List) {
      throw VisitPlannerException(
        (body is Map ? body['message'] : null)?.toString() ??
            'Status work order tidak dapat dimuat.',
      );
    }
    return data
        .whereType<Map>()
        .map(
          (item) => WorkOrderStatus.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  static Future<List<String>> getTopScanKeywords() async {
    final response = await (await GeuApiClient.instance).get(
      '/api/visit-planner/scan/jobs/keywords/top',
    );
    final data = GeuApiClient.unwrapData(response.data);
    if (response.statusCode != 200 || data is! List) return const [];
    return data
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static Future<ScanQuota> getMyScanQuota() async {
    final response = await (await GeuApiClient.instance).get(
      '/api/visit-planner/scan/my-quota',
    );
    final data = GeuApiClient.unwrapData(response.data);
    if (response.statusCode != 200 || data is! Map) {
      throw VisitPlannerException('Kuota scan tidak dapat dimuat.');
    }
    return ScanQuota.fromJson(data);
  }

  static Future<CreatedWorkOrder> createWorkOrder({
    required int supplierId,
    required int statusId,
    required DateTime date,
    DateTime? followUpAt,
  }) async {
    final dio = await GeuApiClient.instance;
    final response = await dio.post(
      '/api/visit-planner/work-order/store',
      data: {
        'supplier_id': supplierId,
        'status_id': statusId,
        'tgl': _date(date),
        if (followUpAt != null) 'call_at': _date(followUpAt),
      },
    );
    final body = response.data;
    final data = body is Map && body['data'] is Map ? body['data'] : body;
    if (response.statusCode != 200 ||
        data is! Map ||
        data['work_order_id'] == null) {
      throw VisitPlannerException(
        (body is Map ? body['message'] : null)?.toString() ??
            'Work order gagal dibuat.',
      );
    }
    return CreatedWorkOrder(
      id: int.tryParse(data['work_order_id'].toString()) ?? 0,
      code: data['kode']?.toString() ?? 'WO #${data['work_order_id']}',
    );
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static Future<List<ScanJob>> getScanJobs() async {
    final dio = await GeuApiClient.instance;
    final response = await dio.get('/api/visit-planner/scan/jobs');
    final body = response.data;
    final data = GeuApiClient.unwrapData(body);
    if (response.statusCode != 200 || data is! List) {
      throw VisitPlannerException('Riwayat scan tidak dapat dimuat.');
    }
    return data
        .whereType<Map>()
        .map((item) => ScanJob.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<int> createScanJob({
    required String keyword,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required double minRating,
    required bool requirePhone,
  }) async {
    final dio = await GeuApiClient.instance;
    final response = await dio.post(
      '/api/visit-planner/scan/jobs',
      data: {
        'keyword': keyword,
        'lat': latitude,
        'lng': longitude,
        'radius': radiusMeters,
        'min_rating': minRating,
        'wajib_no_hp': requirePhone,
      },
    );
    final body = response.data;
    final data = GeuApiClient.unwrapData(body);
    final id = data is Map ? int.tryParse(data['id'].toString()) : null;
    if (response.statusCode != 200 || id == null) {
      throw VisitPlannerException(
        GeuApiClient.responseMessage(body) ?? 'Job scan gagal dibuat.',
      );
    }
    return id;
  }

  static Future<int> runProspectScan({
    required int jobId,
    required String keyword,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required bool requirePhone,
  }) async {
    final response = await (await GeuApiClient.instance).post(
      '/api/visit-planner/scan/google',
      data: {
        'job_id': jobId,
        'keyword': keyword,
        'lat': latitude,
        'lng': longitude,
        'radius': radiusMeters,
        'require_phone': requirePhone,
      },
    );
    final body = response.data;
    final data = GeuApiClient.unwrapData(body);
    if (response.statusCode != 200 || data is! Map) {
      throw VisitPlannerException(
        GeuApiClient.responseMessage(body) ?? 'Scan Google Maps gagal.',
      );
    }
    return int.tryParse(data['saved'].toString()) ?? 0;
  }

  static Future<List<ScannedProspect>> getScannedProspects(ScanJob job) async {
    final dio = await GeuApiClient.instance;
    final response = await dio.get(
      '/api/visit-planner/scanned-places',
      queryParameters: {
        'lat': job.latitude,
        'lng': job.longitude,
        'radius': job.radius,
        'limit': 1000,
        'scan_job_id': job.id,
      },
    );
    final data = GeuApiClient.unwrapData(response.data);
    if (response.statusCode != 200 || data is! List)
      throw VisitPlannerException('Prospek tidak dapat dimuat.');
    return data
        .whereType<Map>()
        .map(
          (item) => ScannedProspect.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  static Future<void> addScannedProspectToMission(int prospectId) async {
    final dio = await GeuApiClient.instance;
    final response = await dio.post(
      '/api/visit-planner/mission/add-scanned',
      data: {'scanned_place_id': prospectId},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw VisitPlannerException(
        GeuApiClient.responseMessage(response.data) ??
            'Prospek gagal ditambahkan ke Mission.',
      );
    }
  }

  static Future<void> updateMissionStatus({
    required int planDetailId,
    required String status,
    String? skipReason,
    DateTime? rescheduleDate,
  }) async {
    final dio = await GeuApiClient.instance;
    final response = await dio.post(
      '/api/visit-planner/mission/status',
      data: {
        'plan_detail_id': planDetailId,
        'status': status,
        if (skipReason != null && skipReason.trim().isNotEmpty)
          'skip_reason': skipReason.trim(),
        if (rescheduleDate != null) 'reschedule_date': _date(rescheduleDate),
      },
    );
    if (response.statusCode != 200)
      throw VisitPlannerException('Status mission gagal diperbarui.');
  }

  static Future<void> addSupplierToMission(int supplierId) async {
    final dio = await GeuApiClient.instance;
    final response = await dio.post(
      '/api/visit-planner/mission/add',
      data: {'supplier_id': supplierId},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw VisitPlannerException(
        GeuApiClient.responseMessage(response.data) ??
            'Supplier gagal ditambahkan ke Mission.',
      );
    }
  }

  static Future<int> registerProspect({
    required String name,
    required String address,
    required String phone,
    required double latitude,
    required double longitude,
    required String employeeName,
    required String employeePosition,
    String accountName = '',
    String accountNumber = '',
    int? bankId,
  }) async {
    final dio = await GeuApiClient.instance;
    final response = await dio.post(
      '/api/visit-planner/prospect/register',
      data: {
        'name': name,
        'alamat': address,
        'phone': phone,
        'lat': latitude,
        'lng': longitude,
        'karyawan': employeeName,
        'jabatan': employeePosition,
        if (accountName.isNotEmpty) 'nama_rek': accountName,
        if (accountNumber.isNotEmpty) 'nomor_rek': accountNumber,
        if (bankId != null) 'bank_rek_id': bankId,
      },
    );
    final data = GeuApiClient.unwrapData(response.data);
    if (response.statusCode != 200 || data is! Map) {
      throw VisitPlannerException('Supplier tidak dapat didaftarkan.');
    }
    final id = int.tryParse(data['supplier_id']?.toString() ?? '');
    if (id == null || id <= 0) {
      throw VisitPlannerException('ID supplier hasil registrasi tidak valid.');
    }
    return id;
  }

  static Future<List<BankOption>> getBanks() async {
    final dio = await GeuApiClient.instance;
    final response = await dio.get('/api/suppliers/dropdowns');
    final data = GeuApiClient.unwrapData(response.data);
    if (response.statusCode != 200 || data is! Map) {
      throw VisitPlannerException('Daftar bank tidak dapat dimuat.');
    }
    return (data['banks'] as List? ?? const [])
        .whereType<Map>()
        .map((bank) => BankOption.fromJson(Map<String, dynamic>.from(bank)))
        .toList();
  }

  static Future<AccountValidation> validateBankAccount({
    required String accountNumber,
    required String bankCode,
    String accountName = '',
  }) async {
    final dio = await GeuApiClient.instance;
    final response = await dio.post(
      '/api/suppliers/validate-account',
      data: {
        'nomor_rek': accountNumber,
        'bank_code': bankCode,
        'nama_rek': accountName,
      },
    );
    final data = GeuApiClient.unwrapData(response.data);
    if (response.statusCode != 200 || data is! Map) {
      throw VisitPlannerException('Validasi rekening gagal.');
    }
    return AccountValidation.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<void> removeFromMission(int planDetailId) async {
    final dio = await GeuApiClient.instance;
    final response = await dio.post(
      '/api/visit-planner/mission/remove',
      data: {'plan_detail_id': planDetailId},
    );
    final body = response.data;
    if (response.statusCode != 200 ||
        (body is Map && body['status'] == 'error')) {
      throw VisitPlannerException(
        (body is Map ? body['message'] : null)?.toString() ??
            'Item gagal dihapus dari Mission.',
      );
    }
  }

  /// Body fields (name/lat/lng/address) follow the naming convention used by
  /// sibling endpoints (createScanJob, getNearbySuppliers) — this route's
  /// exact request schema isn't in doc.md, so confirm against the backend
  /// before relying on it in production.
  static Future<void> addPoiToMission({
    required String name,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    final dio = await GeuApiClient.instance;
    final response = await dio.post(
      '/api/visit-planner/mission/add-poi',
      data: {
        'name': name,
        'lat': latitude,
        'lng': longitude,
        if (address != null && address.isNotEmpty) 'address': address,
      },
    );
    final body = response.data;
    if (response.statusCode != 200 ||
        (body is Map && body['status'] == 'error')) {
      throw VisitPlannerException(
        (body is Map ? body['message'] : null)?.toString() ??
            'POI gagal ditambahkan ke Mission.',
      );
    }
  }

  static Future<List<NearbySupplier>> getNearbySuppliers({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    String? city,
  }) async {
    // Mobile callers use metres (the same unit used by the map and sliders),
    // while the Visit Planner API expects kilometres.
    final radiusKm = radiusMeters / 1000;
    final dio = await GeuApiClient.instance;
    final path = city == null || city.trim().isEmpty
        ? '/api/visit-planner/suppliers/nearby'
        : '/api/visit-planner/suppliers/by-city';
    final response = await dio.get(
      path,
      queryParameters: {
        'lat': latitude,
        'lng': longitude,
        if (city == null || city.trim().isEmpty)
          'radius': radiusKm
        else
          'city_name': city.trim(),
      },
    );
    final data = GeuApiClient.unwrapData(response.data);
    if (response.statusCode != 200 || data is! List)
      throw VisitPlannerException('Supplier tidak dapat dimuat.');
    return data
        .whereType<Map>()
        .map((item) => NearbySupplier.fromJson(Map<String, dynamic>.from(item)))
        // Keep map rendering bounded even if a server/proxy returns an
        // unfiltered response.
        .where((supplier) => supplier.distanceKm <= radiusKm)
        .toList();
  }

  static double? _asDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
}

class WorkOrderStatus {
  final int id;
  final String code;
  final String name;

  const WorkOrderStatus({
    required this.id,
    required this.code,
    required this.name,
  });

  factory WorkOrderStatus.fromJson(Map<String, dynamic> json) =>
      WorkOrderStatus(
        id: int.tryParse(json['id'].toString()) ?? 0,
        code: json['kode']?.toString() ?? '',
        name: json['text']?.toString() ?? json['name']?.toString() ?? '',
      );
}

class ScanQuota {
  final int quota;
  final int pending;
  final int remaining;
  const ScanQuota({
    required this.quota,
    required this.pending,
    required this.remaining,
  });
  factory ScanQuota.fromJson(Map json) => ScanQuota(
    quota: int.tryParse('${json['quota'] ?? 0}') ?? 0,
    pending: int.tryParse('${json['pending'] ?? 0}') ?? 0,
    remaining: int.tryParse('${json['remaining'] ?? 0}') ?? 0,
  );
}

class CreatedWorkOrder {
  final int id;
  final String code;
  const CreatedWorkOrder({required this.id, required this.code});
}

class ScanJob {
  final int id, radius, found, saved;
  final double latitude, longitude;
  final String keyword, status, locationName;
  final DateTime? createdAt;
  const ScanJob({
    required this.id,
    required this.keyword,
    required this.status,
    required this.radius,
    required this.found,
    required this.saved,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    this.createdAt,
  });
  factory ScanJob.fromJson(Map<String, dynamic> json) => ScanJob(
    id: int.tryParse(json['id'].toString()) ?? 0,
    keyword: json['keyword']?.toString() ?? '',
    status: json['status']?.toString() ?? 'pending',
    radius: int.tryParse(json['radius'].toString()) ?? 0,
    found: int.tryParse(json['found'].toString()) ?? 0,
    saved: int.tryParse(json['saved'].toString()) ?? 0,
    latitude: VisitPlannerService._asDouble(json['lat']) ?? 0,
    longitude: VisitPlannerService._asDouble(json['lng']) ?? 0,
    locationName: json['location_name']?.toString() ?? '',
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
  );
}

class ScannedProspect {
  final int id;
  final String name, address, phone, status;
  final double? latitude, longitude;
  const ScannedProspect({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.status,
    this.latitude,
    this.longitude,
  });
  factory ScannedProspect.fromJson(
    Map<String, dynamic> json,
  ) => ScannedProspect(
    id: int.tryParse(json['id'].toString()) ?? 0,
    name: json['name']?.toString() ?? '',
    address: json['address']?.toString() ?? '',
    phone: json['phone']?.toString() ?? '',
    status:
        json['visit_status']?.toString() ?? json['status']?.toString() ?? 'NEW',
    latitude: VisitPlannerService._asDouble(json['lat'] ?? json['latitude']),
    longitude: VisitPlannerService._asDouble(json['lng'] ?? json['longitude']),
  );
}

class BankOption {
  final int id;
  final String name;
  final String code;
  const BankOption({required this.id, required this.name, required this.code});
  factory BankOption.fromJson(Map<String, dynamic> json) => BankOption(
    id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
    name: json['nama_bank']?.toString() ?? '',
    code: json['kode_bank']?.toString() ?? '',
  );
}

class AccountValidation {
  final bool valid;
  final String accountName;
  final bool namesMatch;
  const AccountValidation({
    required this.valid,
    required this.accountName,
    required this.namesMatch,
  });
  factory AccountValidation.fromJson(Map<String, dynamic> json) =>
      AccountValidation(
        valid: json['valid'] == true,
        accountName: json['account_name']?.toString() ?? '',
        namesMatch: json['names_match'] != false,
      );
}

class NearbySupplier {
  final int id;
  final String name, address, phone, type, badge;
  final double distanceKm;
  final double? latitude;
  final double? longitude;
  const NearbySupplier({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.type,
    required this.badge,
    required this.distanceKm,
    this.latitude,
    this.longitude,
  });
  factory NearbySupplier.fromJson(Map<String, dynamic> json) {
    final gps = json['gps']?.toString().split(',') ?? const [];
    return NearbySupplier(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      address: json['alamat']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      type: json['jenis']?.toString() ?? '',
      badge: json['badge_status']?.toString() ?? 'BELUM_WO',
      distanceKm: VisitPlannerService._asDouble(json['distance_km']) ?? 0,
      latitude: gps.length == 2 ? double.tryParse(gps.first.trim()) : null,
      longitude: gps.length == 2 ? double.tryParse(gps.last.trim()) : null,
    );
  }
}
