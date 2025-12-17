import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/surat_jalan.dart';

class SuratJalanService {
  static const String baseUrl =
      'https://erp.greenenergiutama.co.id'; // URL yang sudah di-push

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
            const Duration(seconds: 20), // Extended timeout untuk real API
            onTimeout: () {
              throw const SocketException('Request timeout');
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
        throw HttpException(
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

      // Handle berbagai jenis error dan rethrow untuk production
      if (e is SocketException) {
        if (e.message.contains('timeout')) {
          throw Exception('Request timeout. Silakan coba lagi.');
        }
        throw Exception('Tidak ada koneksi internet. Periksa koneksi Anda.');
      } else if (e is HttpException) {
        throw Exception('Error server: ${e.message}');
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
}
