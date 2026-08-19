import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/surat_jalan.dart';
import '../config/app_config.dart';
import 'persistent_auth_service.dart';

class SuratJalanService {
  static const String baseUrl = AppConfig.serverDomain; // URL yang sudah di-push

  // Debug mode untuk test empty state
  static const bool debugEmptyState = false; // Set true untuk test empty state
  static const bool useMockData = false; // Set false untuk gunakan real API

  /// Mengambil data surat jalan berdasarkan user_id
  static Future<SuratJalanResponse> getSuratJalan({
    required String userId,
    String? status,
    String? date,
    String? dateRange,
  }) async {
    try {
      // Debug mode: return empty response
      if (debugEmptyState) {
        final today = DateTime.now();
        final dateString =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

        final emptyResponse = {
          "status": "success",
          "code": 200,
          "message": "Tidak ada surat jalan untuk user ini",
          "data": {
            "surat_jalan": [],
            "total_count": 0,
            "filters_applied": {
              "user_id": userId,
              "status": "all",
              "date": dateString,
            },
          },
          "timestamp":
              "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')} ${today.hour.toString().padLeft(2, '0')}:${today.minute.toString().padLeft(2, '0')}:${today.second.toString().padLeft(2, '0')}",
        };

        // Simulate network delay
        await Future.delayed(const Duration(seconds: 1));
        return SuratJalanResponse.fromJson(emptyResponse);
      }

      // Mock data mode untuk testing
      if (useMockData) {
        print('📋 Using mock data for testing...');
        final today = DateTime.now();
        final dateString =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

        final mockResponse = {
          "status": "success",
          "code": 200,
          "message": "Surat jalan ditemukan",
          "data": {
            "surat_jalan": [
              {
                "surat_jalan_id": "4077",
                "kode": "GEU-SR-25-LZB0034",
                "tanggal": "2025-12-02",
                "tanggal_formatted": "02 Dec 2025",
                "status": "done",
                "kode_pickup": "GEU-PO-25-LZB0037",
                "driver_name": "Sampurno",
                "plat": "N 8392 EO (MLG)",
                "gudang_name": "Malang",
                "gudang_gps": "-7.912595289234705, 112.65339928360322",
                "supplier_names": "Indri Pandanlandung",
                "total_suppliers": "1",
                "total_qty": "19",
                "total_qty_real": "19",
                "total_liter": "19",
                "total_harga": "123500",
                "progress": {
                  "total_items": "1",
                  "completed_items": "1",
                  "pickup_items": "0",
                  "cancelled_items": "0",
                  "percentage": 100,
                  "status_summary": {
                    "done": "1",
                    "pickup": "0",
                    "pending": 0,
                    "cancelled": "0",
                  },
                },
                "created_at": "2025-12-01 15:02:58",
                "updated_at": "2025-12-02 14:23:04",
                "surat_jalan_detail": [
                  {
                    "surat_jalan_detail_id": "5767",
                    "supplier_name": "Indri Pandanlandung",
                    "supplier_alamat":
                        "Perum Pondok Mutiara Asri Blok F10/31.pandan landung Wagir Kab Malang",
                    "work_order_kode": "GEU-WO-25-LZA0149",
                    "qty_order": "20",
                    "qty_real": "19",
                    "harga": "6500.00",
                    "satuan": "UCO (Liter)",
                    "status": "done",
                    "supplier_gps": "-7.9731357,112.5780605",
                    "supplier_gps_user": null,
                    "surat_jalan_detail_gps": "-7.9737179,112.580239",
                  },
                ],
              },
              {
                "surat_jalan_id": "4076",
                "kode": "GEU-SR-25-LZB0033",
                "tanggal": "2025-12-02",
                "tanggal_formatted": "02 Dec 2025",
                "status": "pickup",
                "kode_pickup": "GEU-PO-25-LZB0038",
                "driver_name": "Budi Santoso",
                "plat": "N 1234 AB (MLG)",
                "gudang_name": "Malang",
                "gudang_gps": "-7.912595289234705, 112.65339928360322",
                "supplier_names": "Golden Onion",
                "total_suppliers": "1",
                "total_qty": "22",
                "total_qty_real": "22",
                "total_liter": "22",
                "total_harga": "143000",
                "progress": {
                  "total_items": "1",
                  "completed_items": "0",
                  "pickup_items": "1",
                  "cancelled_items": "0",
                  "percentage": 75,
                  "status_summary": {
                    "done": "0",
                    "pickup": "1",
                    "pending": 0,
                    "cancelled": "0",
                  },
                },
                "created_at": "2025-12-01 15:02:54",
                "updated_at": "2025-12-02 13:44:02",
                "surat_jalan_detail": [
                  {
                    "surat_jalan_detail_id": "5766",
                    "supplier_name": "Golden Onion",
                    "supplier_alamat":
                        "Perumahan Kresna Asri Blok K6 Niwin Sidorahayu Wagir Malang",
                    "work_order_kode": "GEU-WO-25-LZA0150",
                    "qty_order": "20",
                    "qty_real": "22",
                    "harga": "6500.00",
                    "satuan": "UCO (Liter)",
                    "status": "pickup",
                    "supplier_gps": "-8.0014273,112.5883108",
                    "supplier_gps_user": null,
                    "surat_jalan_detail_gps": "-8.0027228,112.5915068",
                  },
                ],
              },
            ],
            "total_count": 2,
            "filters_applied": {
              "user_id": userId,
              "status": "all",
              "date": dateString,
            },
          },
          "timestamp":
              "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')} ${today.hour.toString().padLeft(2, '0')}:${today.minute.toString().padLeft(2, '0')}:${today.second.toString().padLeft(2, '0')}",
        };

        // Simulate network delay
        await Future.delayed(const Duration(seconds: 2));
        return SuratJalanResponse.fromJson(mockResponse);
      }
      // Buat URL dengan query parameters
      final Map<String, String> queryParams = {
        'user_id': userId,
        if (status != null) 'status': status,
        if (dateRange != null) 'date': dateRange,
        if (date != null && dateRange == null) 'date': date,
      };

      final uri = Uri.parse(
        '$baseUrl/api/surat_jalan',
      ).replace(queryParameters: queryParams);

      print('🔍 Calling REAL Surat Jalan API:');
      print('📍 URL: $uri');
      print('👤 User ID: $userId');
      print('📅 Date: ${date ?? "not set"}');
      print('📅 DateRange: ${dateRange ?? "not set"}');
      print('🔍 Status Filter: ${status ?? "all"}');
      print('🔗 Final Query Params: $queryParams');

      // Lakukan HTTP GET request
      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'User-Agent': 'OneLink-Mobile/1.0',
              'Cache-Control': 'no-cache',
            },
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              throw io.SocketException('Request timeout');
            },
          );
      ;

      // Cek status code response
      print('🔄 Response Status: ${response.statusCode}');
      print(
        '📜 Response Body: ${response.body.substring(0, response.body.length > 1000 ? 1000 : response.body.length)}...',
      );

      if (response.statusCode == 200) {
        try {
          // Parse JSON response
          final Map<String, dynamic> jsonData = json.decode(response.body);
          print('✅ JSON parsed successfully');

          // Debug: Check data structure
          final data = jsonData['data'];
          if (data != null && data['surat_jalan'] != null) {
            final suratJalanList = data['surat_jalan'] as List;
            print('📊 Data received:');
            print('  - Total count: ${data['total_count'] ?? 'not specified'}');
            print('  - Surat jalan array length: ${suratJalanList.length}');
            print(
              '  - First item ID: ${suratJalanList.isNotEmpty ? suratJalanList[0]['surat_jalan_id'] : 'none'}',
            );

            // Print all IDs for debugging
            for (int i = 0; i < suratJalanList.length; i++) {
              final item = suratJalanList[i];
              print(
                '  - Item $i: ID=${item['surat_jalan_id']}, Kode=${item['kode']}, Status=${item['status']}',
              );
            }
          }

          return SuratJalanResponse.fromJson(jsonData);
        } catch (parseError) {
          print('❌ JSON Parse Error: $parseError');
          throw FormatException('Invalid JSON response: $parseError');
        }
      } else {
        print('❌ HTTP Error ${response.statusCode}: ${response.body}');
        throw io.HttpException(
          'Failed to load surat jalan. Status: ${response.statusCode}, Body: ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Surat Jalan API Error: $e');
      print('📊 Request Details:');
      print('  - User ID: $userId');
      print('  - Date: ${date ?? "not set"}');
      print('  - DateRange: ${dateRange ?? "not set"}');
      print('  - Status: ${status ?? "all"}');

      if (e is io.SocketException) {
        throw Exception('Tidak ada koneksi internet atau request timeout. Periksa koneksi Anda.');
      } else if (e is io.HttpException) {
        throw Exception('Error server: ${(e as io.HttpException).message}');
      } else if (e is FormatException) {
        throw Exception('Format data tidak valid dari server.');
      } else {
        throw Exception('Error tidak terduga: ${e.toString()}');
      }
    }
  }

  /// Fallback mock data
  static Future<SuratJalanResponse> _getMockData(
    String userId,
    String? date,
  ) async {
    final today = DateTime.now();
    final dateString =
        date ??
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final mockResponse = {
      "status": "success",
      "code": 200,
      "message": "Surat jalan ditemukan (Mock Data)",
      "data": {
        "surat_jalan": [
          {
            "surat_jalan_id": "4077",
            "kode": "GEU-SR-25-LZB0034",
            "tanggal": "2025-12-02",
            "tanggal_formatted": "02 Dec 2025",
            "status": "done",
            "kode_pickup": "GEU-PO-25-LZB0037",
            "driver_name": "Sampurno",
            "plat": "N 8392 EO (MLG)",
            "gudang_name": "Malang",
            "gudang_gps": "-7.912595289234705, 112.65339928360322",
            "supplier_names": "Indri Pandanlandung",
            "total_suppliers": "1",
            "total_qty": "19",
            "total_qty_real": "19",
            "total_liter": "19",
            "total_harga": "123500",
            "progress": {
              "total_items": "1",
              "completed_items": "1",
              "pickup_items": "0",
              "cancelled_items": "0",
              "percentage": 100,
              "status_summary": {
                "done": "1",
                "pickup": "0",
                "pending": 0,
                "cancelled": "0",
              },
            },
            "created_at": "2025-12-01 15:02:58",
            "updated_at": "2025-12-02 14:23:04",
            "surat_jalan_detail": [
              {
                "surat_jalan_detail_id": "5767",
                "supplier_name": "Indri Pandanlandung",
                "supplier_alamat":
                    "Perum Pondok Mutiara Asri Blok F10/31.pandan landung Wagir Kab Malang",
                "work_order_kode": "GEU-WO-25-LZA0149",
                "qty_order": "20",
                "qty_real": "19",
                "harga": "6500.00",
                "satuan": "UCO (Liter)",
                "status": "done",
                "supplier_gps": "-7.9731357,112.5780605",
                "supplier_gps_user": null,
                "surat_jalan_detail_gps": "-7.9737179,112.580239",
              },
            ],
          },
          {
            "surat_jalan_id": "4076",
            "kode": "GEU-SR-25-LZB0033",
            "tanggal": "2025-12-02",
            "tanggal_formatted": "02 Dec 2025",
            "status": "pickup",
            "kode_pickup": "GEU-PO-25-LZB0038",
            "driver_name": "Budi Santoso",
            "plat": "N 1234 AB (MLG)",
            "gudang_name": "Malang",
            "gudang_gps": "-7.912595289234705, 112.65339928360322",
            "supplier_names": "Golden Onion",
            "total_suppliers": "1",
            "total_qty": "22",
            "total_qty_real": "22",
            "total_liter": "22",
            "total_harga": "143000",
            "progress": {
              "total_items": "1",
              "completed_items": "0",
              "pickup_items": "1",
              "cancelled_items": "0",
              "percentage": 75,
              "status_summary": {
                "done": "0",
                "pickup": "1",
                "pending": 0,
                "cancelled": "0",
              },
            },
            "created_at": "2025-12-01 15:02:54",
            "updated_at": "2025-12-02 13:44:02",
            "surat_jalan_detail": [
              {
                "surat_jalan_detail_id": "5766",
                "supplier_name": "Golden Onion",
                "supplier_alamat":
                    "Perumahan Kresna Asri Blok K6 Niwin Sidorahayu Wagir Malang",
                "work_order_kode": "GEU-WO-25-LZA0150",
                "qty_order": "20",
                "qty_real": "22",
                "harga": "6500.00",
                "satuan": "UCO (Liter)",
                "status": "pickup",
                "supplier_gps": "-8.0014273,112.5883108",
                "supplier_gps_user": null,
                "surat_jalan_detail_gps": "-8.0027228,112.5915068",
              },
            ],
          },
          {
            "surat_jalan_id": "4081",
            "kode": "GEU-SR-25-LZB0038",
            "tanggal": "2025-12-02",
            "tanggal_formatted": "02 Dec 2025",
            "status": "pending",
            "kode_pickup": "GEU-PO-25-LZB0026",
            "driver_name": "Ahmad Yusuf",
            "plat": "N 5678 CD (MLG)",
            "gudang_name": "Malang",
            "gudang_gps": "-7.912595289234705, 112.65339928360322",
            "supplier_names": "Dewi Yonzipur",
            "total_suppliers": "1",
            "total_qty": "110",
            "total_qty_real": "0",
            "total_liter": "110",
            "total_harga": "880000",
            "progress": {
              "total_items": "1",
              "completed_items": "0",
              "pickup_items": "0",
              "cancelled_items": "0",
              "percentage": 0,
              "status_summary": {
                "done": "0",
                "pickup": "0",
                "pending": 1,
                "cancelled": "0",
              },
            },
            "created_at": "2025-12-01 15:03:21",
            "updated_at": "2025-12-02 12:05:06",
            "surat_jalan_detail": [
              {
                "surat_jalan_detail_id": "5771",
                "supplier_name": "Dewi Yonzipur",
                "supplier_alamat":
                    "Yon Zipur 5 Kepanjen Panggungrejo Malang Panggungrejo Kec Kepanjen Kab Malang",
                "work_order_kode": "GEU-WO-25-LZA0029",
                "qty_order": "100",
                "qty_real": "0",
                "harga": "8000.00",
                "satuan": "UCO (Liter)",
                "status": "pending",
                "supplier_gps": "-8.1456098,112.5649821",
                "supplier_gps_user": null,
                "surat_jalan_detail_gps":
                    "-7.945142645205245,112.62018585249531",
              },
            ],
          },
        ],
        "total_count": 3,
        "filters_applied": {
          "user_id": userId,
          "status": "all",
          "date": dateString,
        },
      },
      "timestamp":
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')} ${today.hour.toString().padLeft(2, '0')}:${today.minute.toString().padLeft(2, '0')}:${today.second.toString().padLeft(2, '0')}",
    };

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    return SuratJalanResponse.fromJson(mockResponse);
  }

  /// Mengambil surat jalan untuk hari ini dengan user_id tertentu
  static Future<SuratJalanResponse> getTodaySuratJalan(String userId) async {
    final today = DateTime.now();
    final dateString =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    return await getSuratJalan(userId: userId, date: dateString);
  }

  /// Format currency untuk menampilkan harga
  static String formatCurrency(String amount) {
    try {
      final double value = double.parse(amount);
      final formatter = value
          .toStringAsFixed(0)
          .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match match) => '${match[1]},',
          );
      return 'Rp $formatter';
    } catch (e) {
      return 'Rp $amount';
    }
  }

  /// Get status badge color berdasarkan status surat jalan
  static String getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'done':
        return 'green';
      case 'pickup':
        return 'orange';
      case 'pending':
        return 'yellow';
      case 'cancelled':
        return 'red';
      default:
        return 'gray';
    }
  }

  /// Get progress percentage color
  static String getProgressColor(int percentage) {
    if (percentage >= 100) {
      return 'green';
    } else if (percentage >= 75) {
      return 'blue';
    } else if (percentage >= 50) {
      return 'orange';
    } else {
      return 'red';
    }
  }

  /// Convert liter to kg (UCO density ~0.9 kg/L)
  static String convertLiterToKg(String literAmount) {
    try {
      final double liter = double.parse(literAmount);
      final double kg = liter * 0.9; // UCO density approximation
      return kg.toStringAsFixed(1);
    } catch (e) {
      return '0.0';
    }
  }

  /// Format quantity with unit conversion
  static String formatQuantityWithUnit(String amount, String unit) {
    try {
      if (unit.toLowerCase().contains('liter') ||
          unit.toLowerCase().contains('l')) {
        final kg = convertLiterToKg(amount);
        return '${kg} kg';
      } else {
        return '$amount kg';
      }
    } catch (e) {
      return '$amount kg';
    }
  }

  /// Fetch pickup history using the newly created API
  static Future<List<SuratJalan>> getPickupHistory({
    required String userId,
    int page = 1,
  }) async {
    print('✅ History: User ID set to: $userId');
    print('🔍 History: Loading history data for user: $userId');

    try {
      final queryParams = {
        'user_id': userId,
        'page': page.toString(),
        'limit': '50',
      };
      
      // Trying the PRD endpoint first
      final uri = Uri.parse('$baseUrl/api/v1/surat-jalan/history').replace(
        queryParameters: queryParams,
      );

      print('🔍 Calling REAL History API:');
      print('📍 URL: $uri');
      print('👤 User ID: $userId');
      print('🔗 Final Query Params: $queryParams');

      final token = await PersistentAuthService.instance.getToken();

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'OneLink-Mobile/1.0',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      print('🔄 Response Status: ${response.statusCode}');
      print('📜 Response Body: ${response.body.length > 500 ? response.body.substring(0, 500) + '...' : response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        print('✅ JSON parsed successfully');

        dynamic rawItems;
        dynamic rawPagination;
        
        if (jsonData['data'] != null) {
          if (jsonData['data']['items'] != null) {
            rawItems = jsonData['data']['items'];
            rawPagination = jsonData['data']['pagination'];
          } else if (jsonData['data']['data'] != null && jsonData['data']['data']['items'] != null) {
            // Nested structure returned by the actual backend
            rawItems = jsonData['data']['data']['items'];
            rawPagination = jsonData['data']['data']['pagination'];
          }
        }

        if (rawItems != null) {
          final items = rawItems as List;

          print('📊 Data received:');
          print('  - Total count: ${rawPagination?['total_items'] ?? items.length}');
          print('  - History array length: ${items.length}');
          print('  - First item ID: ${items.isNotEmpty ? items.first['id'] : 'none'}');
          print('✅ History: Data loaded successfully');
          print('🗺️ Setting up map markers for ${items.length} surat jalan');

          return items.map<SuratJalan>((e) {
            // Mapping back actual backend dictionary to SuratJalan model fallback structure
            final statusStr = e['status']?.toString() ?? 'done';
            
            return SuratJalan(
              suratJalanId: e['id']?.toString() ?? '0',
              kode: e['kode'] ?? '-',
              tanggal: e['date'] ?? '-',
              tanggalFormatted: e['date'] != null ? e['date'].toString().split('T')[0] : '-',
              status: statusStr.toLowerCase() == 'cancel' ? 'cancelled' : statusStr,
              kodePickup: e['kode_pickup'] ?? '-',
              driverName: e['driver_name'] ?? '-',
              plat: e['plat'] ?? '-',
              gudangName: e['gudang_name'] ?? '-',
              gudangGps: e['gudang_gps'] ?? '-',
              supplierNames: '-',
              totalSuppliers: e['total_supplier']?.toString() ?? '0',
              totalQty: e['total_qty']?.toString() ?? '0',
              totalQtyReal: '0',
              // Since total_kg is missing from backend, we map total_qty as liter
              totalLiter: e['total_qty']?.toString() ?? '0',
              totalHarga: '0',
              createdAt: e['created_at'] ?? e['date'] ?? '',
              updatedAt: e['updated_at'] ?? e['date'] ?? '',
              progress: Progress(
                totalItems: '0', completedItems: '0', pickupItems: '0', cancelledItems: '0', percentage: 100,
                statusSummary: StatusSummary(done: '0', pickup: '0', pending: 0, cancelled: '0'),
              ),
              suratJalanDetail: [],
            );
          }).toList();
        }
      }
    } catch (e) {
      print('❌ Error PRD endpoint: $e, falling back to legacy endpoint');
    }

    // Fallback: Using existing getSuratJalan but we just want history (done, cancelled)
    try {
      print('⚠️ History: Falling back to getSuratJalan legacy endpoint...');
      final response = await getSuratJalan(userId: userId);
      // Filter out only done and cancelled to mimic history
      final historyList = response.data.suratJalan.where((s) {
        final st = s.status.toLowerCase();
        return st == 'done' || st == 'cancelled';
      }).toList();

      print('📊 Fallback data received:');
      print('  - Total count: ${response.data.totalCount}');
      print('  - History array length: ${historyList.length}');
      print('  - First item ID: ${historyList.isNotEmpty ? historyList.first.suratJalanId : 'none'}');
      print('✅ History (Fallback): Data loaded successfully');

      return historyList;
    } catch (e) {
      print('❌ Both endpoints failed: $e');
      throw Exception('Gagal memuat riwayat penjemputan: $e');
    }
  }

  /// Fetch detail of a specific history using the PRD API
  static Future<SuratJalan> getPickupHistoryDetail(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/surat-jalan/history/$id');
      print('🔍 Calling REAL History Detail API:');
      print('📍 URL: $uri');

      final token = await PersistentAuthService.instance.getToken();
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'OneLink-Mobile/1.0',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      print('🔄 Response Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        
        dynamic rawData;
        if (jsonData['data'] != null) {
           rawData = jsonData['data'];
           if (rawData['data'] != null) { // Handle double nested
             rawData = rawData['data'];
           }
        }
        
        if (rawData != null) {
           final e = rawData;
           final statusStr = e['status']?.toString() ?? 'done';
           
           return SuratJalan(
              suratJalanId: e['id']?.toString() ?? e['surat_jalan_id']?.toString() ?? '0',
              kode: e['kode'] ?? '-',
              tanggal: e['date'] ?? e['tanggal'] ?? '-',
              tanggalFormatted: e['date'] != null ? e['date'].toString().split('T')[0] : (e['tanggal_formatted'] ?? '-'),
              status: statusStr.toLowerCase() == 'cancel' ? 'cancelled' : statusStr,
              kodePickup: e['kode_pickup'] ?? '-',
              driverName: e['driver_name'] ?? '-',
              plat: e['plat_no'] ?? e['plat'] ?? '-',
              gudangName: e['gudang_name'] ?? '-',
              gudangGps: e['gudang_gps'] ?? '-',
              supplierNames: e['supplier_names'] ?? '-',
              totalSuppliers: e['total_supplier']?.toString() ?? e['total_suppliers']?.toString() ?? '0',
              totalQty: e['total_qty']?.toString() ?? '0',
              totalQtyReal: e['total_qty_real']?.toString() ?? '0',
              totalLiter: e['total_kg']?.toString() ?? e['total_liter']?.toString() ?? e['total_qty']?.toString() ?? '0',
              totalHarga: e['total_harga']?.toString() ?? '0',
              createdAt: e['created_at'] ?? e['date'] ?? '',
              updatedAt: e['updated_at'] ?? e['date'] ?? '',
              progress: Progress(
                totalItems: '0', completedItems: '0', pickupItems: '0', cancelledItems: '0', percentage: 100,
                statusSummary: StatusSummary(done: '0', pickup: '0', pending: 0, cancelled: '0'),
              ),
              suratJalanDetail: ((e['surat_jalan_detail'] ?? e['details'] ?? e['items']) as List?)?.map((item) => SuratJalanDetail.fromJson(item)).toList() ?? [],
           );
        }
      }
      throw Exception('Format data tidak dikenali atau detail tidak ditemukan');
    } catch (e) {
      print('❌ Error PRD Detail endpoint: $e');
      throw Exception('Gagal memuat detail riwayat penjemputan: $e');
    }
  }

  // ── NEW 3-STEP API FLOW ──────────────────────────────────

  /// STEP 1: Simpan Tanda Tangan (Base64)
  static Future<bool> saveSignatureApi({
    required int detailId,
    required String ttdBase64,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/surat_jalan_ttd');
      print('📤 Step 1: Saving TTD for ID: $detailId');
      
      final response = await http.post(
        uri,
        body: {
          'id': detailId.toString(),
          'ttd': ttdBase64,
        },
      ).timeout(const Duration(seconds: 20));

      print('🔄 TTD Response Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final success = data['status'] == 'success';
        if (success) print('✅ Step 1 Success: TTD saved');
        return success;
      }
      return false;
    } catch (e) {
      print('❌ Step 1 Error: $e');
      throw Exception('Gagal menyimpan tanda tangan: $e');
    }
  }

  /// STEP 2: Upload Foto Bukti (Base64)
  static Future<bool> savePhotoApi({
    required int detailId,
    required String photoBase64,
    double? lat,
    double? lng,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/surat_jalan_foto');
      print('📤 Step 2: Uploading Photo for ID: $detailId');
      
      final body = {
        'id': detailId.toString(),
        'foto': photoBase64,
        if (lat != null) 'gps_latitude': lat.toString(),
        if (lng != null) 'gps_longitude': lng.toString(),
      };

      final response = await http.post(
        uri,
        body: body,
      ).timeout(const Duration(seconds: 30));

      print('🔄 Photo Response Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final success = data['status'] == 'success';
        if (success) print('✅ Step 2 Success: Photo uploaded');
        return success;
      }
      return false;
    } catch (e) {
      print('❌ Step 2 Error: $e');
      throw Exception('Gagal mengupload foto: $e');
    }
  }

  /// STEP 3: Update Status (PALING AKHIR!)
  static Future<bool> updateStatusApi({
    required int detailId,
    required String status,
    String? qtyReal,
    String? reason,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/surat_jalan_update_status');
      print('📤 Step 3: Updating Status to $status for ID: $detailId');
      
      final body = {
        'id': detailId.toString(),
        'status': status,
        if (qtyReal != null) 'qty_real': qtyReal,
        if (reason != null) 'keterangan_cancel': reason,
      };

      final response = await http.post(
        uri,
        body: body,
      ).timeout(const Duration(seconds: 20));

      print('🔄 Status Response Status: ${response.statusCode}');
      print('📜 Status Response Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final success = data['status'] == 'success';
        if (success) {
          print('✅ Step 3 Success: Status updated to $status');
          if (data['data'] != null) {
            print('📊 Parent SJ Status: ${data['data']['surat_jalan_status']}');
          }
        }
        return success;
      }
      return false;
    } catch (e) {
      print('❌ Step 3 Error: $e');
      throw Exception('Gagal memperbarui status: $e');
    }
  }
}
