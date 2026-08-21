import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/geu/surat_jalan_models.dart';
import '../../models/surat_jalan.dart';
import '../user_storage.dart';
import 'geu_api_client.dart';

/// One photo queued for upload — [bytes] must already be watermarked +
/// WebP-encoded (PhotoWatermarkService.applyAndEncode).
class GeuPhotoUpload {
  final Uint8List bytes;
  final String photoType;
  final String? description;

  GeuPhotoUpload({required this.bytes, required this.photoType, this.description});
}

/// Driver-facing Surat Jalan calls against the new Go API
/// (apipi.greenenergiutama.co.id/api-tms/surat-jalan/*), replacing the old
/// PHP endpoints in lib/services/surat_jalan_service.dart. Uses the same
/// GeuApiClient session (cookie httpOnly) established via
/// GeuAuthService.verifyDriverOtp() — call that first, this throws a plain
/// Exception with the backend's own message on any 401/403/validation
/// error so screens can show it directly.
class GeuSuratJalanService {
  static const String _base = '/api-tms/surat-jalan';

  static Exception _errorFrom(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return Exception(data['message'].toString());
    }
    return Exception(fallback);
  }

  static dynamic _unwrap(Response res) {
    final body = res.data;
    if (body is Map && body['status'] != 'success') {
      throw Exception(body['message']?.toString() ?? 'Permintaan gagal');
    }
    return body is Map ? body['data'] : body;
  }

  /// List SJ the logged-in driver can see (backend scopes by gudang
  /// membership — see driverGudangMember() in surat_jalan_service.go).
  static Future<List<SuratJalan>> listForDriver({
    String? status,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.get(
        _base,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (status != null && status.isNotEmpty) 'status': status,
          if (dateFrom != null) 'date_from': dateFrom,
          if (dateTo != null) 'date_to': dateTo,
        },
      );
      final data = _unwrap(res);
      final items = (data is Map ? data['data'] : null) as List? ?? const [];
      return items
          .map((e) => GeuSuratJalanListItem.fromJson(Map<String, dynamic>.from(e)).toLegacy())
          .toList();
    } on DioException catch (e) {
      throw _errorFrom(e, 'Gagal memuat daftar surat jalan');
    }
  }

  /// Today's SJ for the driver — mirrors the old getTodaySuratJalan() helper.
  static Future<List<SuratJalan>> listToday() {
    final today = DateTime.now();
    final dateStr =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return listForDriver(dateFrom: dateStr, dateTo: dateStr);
  }

  /// Same as [listToday], but each item is additionally hydrated via
  /// [getById] so `suratJalanDetail` (per-supplier rows: names, GPS,
  /// status) is populated — the list endpoint alone only returns a summary.
  /// Dashboard map markers and today's-progress stats both read
  /// `suratJalanDetail`, so this is what the dashboard should call instead
  /// of [listToday] directly. A driver's daily list is small (a handful of
  /// pickups), so the extra round-trips are cheap and run in parallel.
  static Future<String> _getCacheKey() async {
    final userId = await UserStorage.getUserId();
    return 'tms_cached_today_surat_jalan_json_${userId ?? 0}_v1';
  }

  static Future<void> _cacheTodaySuratJalan(List<SuratJalan> list) async {
    try {
      final key = await _getCacheKey();
      final prefs = await SharedPreferences.getInstance();
      final jsonList = list.map((s) => s.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
    } catch (_) {}
  }

  static Future<List<SuratJalan>> _getCachedTodaySuratJalan() async {
    try {
      final key = await _getCacheKey();
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(key);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> raw = jsonDecode(str);
        return raw.map((item) => SuratJalan.fromJson(Map<String, dynamic>.from(item))).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<SuratJalan>> listTodayHydrated() async {
    try {
      final shallow = await listToday();
      final hydrated = await Future.wait(
        shallow.map((s) async {
          try {
            final full = await getById(int.parse(s.suratJalanId));
            return mergeListFields(base: full, listItem: s);
          } catch (_) {
            return s;
          }
        }),
      );
      await _cacheTodaySuratJalan(hydrated);
      return hydrated;
    } catch (e) {
      final cached = await _getCachedTodaySuratJalan();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  /// Fills in fields the detail endpoint doesn't carry (driver/fleet/gudang
  /// *name* only lives in the List response's JOINs) with the shallow list
  /// item's values, keeping everything else from the hydrated detail.
  /// driverId is the exception: the List response never had it (only
  /// driver_name, see SuratJalanListResponse in the Go API), so keep
  /// `base.driverId` — getById()'s header carries it via the raw Pickup
  /// relation (`pickup.driver_id`).
  static SuratJalan mergeListFields({
    required SuratJalan base,
    required SuratJalan listItem,
  }) {
    return SuratJalan(
      suratJalanId: base.suratJalanId,
      kode: base.kode,
      tanggal: base.tanggal,
      tanggalFormatted: base.tanggalFormatted,
      status: base.status,
      kodePickup: listItem.kodePickup,
      driverId: base.driverId,
      driverName: listItem.driverName,
      plat: listItem.plat,
      gudangName: listItem.gudangName,
      gudangGps: listItem.gudangGps,
      supplierNames: base.supplierNames,
      totalSuppliers: base.totalSuppliers,
      totalQty: base.totalQty,
      totalQtyReal: base.totalQtyReal,
      totalLiter: base.totalLiter,
      totalHarga: base.totalHarga,
      progress: base.progress,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      suratJalanDetail: base.suratJalanDetail,
    );
  }

  /// Fully-hydrated SJ (header + real per-supplier detail rows) — call this
  /// when the driver opens a card, since the list endpoint above only
  /// returns a shallow summary.
  static Future<SuratJalan> getById(int id) async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.get('$_base/$id');
      final data = _unwrap(res) as Map;
      final header = GeuSuratJalanHeader.fromJson(Map<String, dynamic>.from(data['header']));
      final rawDetails = (data['details'] as List?) ?? const [];
      final details = rawDetails
          .map((e) => GeuSuratJalanDetail.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      // UploadDetailPhoto (surat_jalan_service_detail.go) only inserts into
      // t_surat_jalan_detail_photos — it never backfills the legacy
      // singular t_surat_jalan_detail.foto column. So `detail.foto` (and
      // therefore detail.fotoUrl) stays null even when photos were
      // uploaded through the driver app, and the detail screen showed
      // "Belum ada foto pickup" despite real uploads existing. Fetch the
      // real per-photo list for any detail that reports photoCount > 0.
      final withPhotos = await Future.wait(details.map((d) async {
        if (d.photoCount == 0) return d;
        try {
          final photos = await getDetailPhotos(d.id);
          return d.copyWithPhotoUrls(photos.map((p) => p.filePath).toList());
        } catch (_) {
          return d;
        }
      }));

      return buildLegacySuratJalan(header, withPhotos);
    } on DioException catch (e) {
      throw _errorFrom(e, 'Gagal memuat detail surat jalan');
    }
  }

  static Future<List<GeuSuratJalanPhoto>> getDetailPhotos(int detailId) async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.get('$_base/detail/$detailId/photos');
      final data = _unwrap(res) as Map;
      final items = (data['photos'] as List?) ?? const [];
      return items.map((e) => GeuSuratJalanPhoto.fromJson(Map<String, dynamic>.from(e))).toList();
    } on DioException catch (e) {
      throw _errorFrom(e, 'Gagal memuat foto detail');
    }
  }

  /// Saves GPS for one detail item ("lat,lng"). Required before the item
  /// can be marked done (Go backend validates this, see
  /// UpdateDetailStatus in surat_jalan_service_detail.go).
  static Future<void> saveGps(int detailId, double lat, double lng) async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.post(
        '$_base/detail/$detailId/gps',
        data: {'gps': '$lat,$lng'},
      );
      _unwrap(res);
    } on DioException catch (e) {
      throw _errorFrom(e, 'Gagal menyimpan lokasi GPS');
    }
  }

  /// [webpBytes] must already be WebP (see PhotoWatermarkService.toWebp) —
  /// the backend rejects any other format.
  static Future<void> saveTtd(int detailId, Uint8List webpBytes) async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.post(
        '$_base/detail/$detailId/ttd',
        data: {'base64_data': base64Encode(webpBytes)},
      );
      _unwrap(res);
    } on DioException catch (e) {
      throw _errorFrom(e, 'Gagal menyimpan tanda tangan');
    }
  }

  /// Uploads one or more photos in a single call — mirrors the web app's
  /// multi-photo flow (application/views/surat-jalan/new_take.php: up to
  /// 10 photos per detail, each with its own type). Each item's `bytes`
  /// must already be watermarked + WebP-encoded (see
  /// PhotoWatermarkService.applyAndEncode) — the backend rejects any other
  /// format.
  static Future<void> uploadPhotos(
    int detailId,
    List<GeuPhotoUpload> photos, {
    double? lat,
    double? lng,
  }) async {
    if (photos.isEmpty) return;
    try {
      final dio = await GeuApiClient.instance;
      final metadata = photos
          .map((p) => {
                'photo_type': p.photoType,
                'description': p.description ?? '',
                if (lat != null) 'gps_latitude': lat,
                if (lng != null) 'gps_longitude': lng,
              })
          .toList();
      final form = FormData.fromMap({
        'photos': [
          for (var i = 0; i < photos.length; i++)
            MultipartFile.fromBytes(
              photos[i].bytes,
              filename: 'bukti_${detailId}_$i.webp',
            ),
        ],
        'photos_data': jsonEncode(metadata),
        if (lat != null) 'gps_latitude': lat.toString(),
        if (lng != null) 'gps_longitude': lng.toString(),
      });
      final res = await dio.post('$_base/detail/$detailId/photos', data: form);
      _unwrap(res);
    } on DioException catch (e) {
      throw _errorFrom(e, 'Gagal mengunggah foto bukti');
    }
  }

  /// Final step — marks the detail item done/cancel. For `done`, the
  /// backend requires TTD + GPS + at least 1 photo + qtyReal > 0 to already
  /// be saved (call saveGps/saveTtd/uploadPhoto first). Marking the LAST
  /// remaining item done auto-flips the parent Surat Jalan header to done.
  static Future<void> updateStatus(
    int detailId, {
    required String status,
    double? qtyReal,
    String? keteranganCancel,
  }) async {
    try {
      final dio = await GeuApiClient.instance;
      final res = await dio.put(
        '$_base/detail/$detailId/status',
        data: {
          'status': status,
          if (qtyReal != null) 'qty_real': qtyReal,
          if (keteranganCancel != null) 'keterangan_cancel': keteranganCancel,
        },
      );
      _unwrap(res);
    } on DioException catch (e) {
      throw _errorFrom(e, 'Gagal memperbarui status');
    }
  }
}
