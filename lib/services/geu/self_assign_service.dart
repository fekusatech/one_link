import 'geu_api_client.dart';

class SelfAssignSupplier {
  final int id;
  final String name;
  final String code;
  final String phone;
  final String city;
  final String type;

  const SelfAssignSupplier({
    required this.id,
    required this.name,
    required this.code,
    required this.phone,
    required this.city,
    required this.type,
  });

  factory SelfAssignSupplier.fromJson(Map<String, dynamic> json) =>
      SelfAssignSupplier(
        id: int.tryParse((json['id'] ?? 0).toString()) ?? 0,
        name: (json['name'] ?? '-').toString(),
        code: (json['kode_poo'] ?? '-').toString(),
        phone: (json['phone'] ?? '').toString(),
        city: (json['kota'] ?? '').toString(),
        type: (json['jenis'] ?? '').toString(),
      );
}

class SelfAssignPageData {
  final List<SelfAssignSupplier> suppliers;
  final bool hasNext;
  const SelfAssignPageData({required this.suppliers, required this.hasNext});
}

class SelfAssignService {
  static Future<List<Map<String, dynamic>>> myClaims({
    String search = '',
  }) async {
    final response = await (await GeuApiClient.instance).get(
      '/api-crm/self-assign/my-claims',
      queryParameters: {if (search.isNotEmpty) 'search': search},
    );
    final body = response.data;
    final data = GeuApiClient.unwrapData(body);
    if (response.statusCode != 200 || data is! List) {
      throw Exception(
        (body is Map ? body['message'] : null) ??
            'Klaim saya tidak dapat dimuat.',
      );
    }
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<void> escalate({
    required int supplierId,
    required String notes,
    required String recommendation,
    double? revisitPrice,
  }) async {
    final response = await (await GeuApiClient.instance).post(
      '/api-crm/self-assign/escalate',
      data: {
        'supplier_id': supplierId,
        'notes': notes,
        'recommendation': recommendation,
        if (revisitPrice != null) 'harga_revisit': revisitPrice,
      },
    );
    if (response.statusCode != 200 ||
        (response.data is Map && response.data['status'] == 'error')) {
      throw Exception(
        (response.data is Map ? response.data['message'] : null) ??
            'Eskalasi gagal dikirim.',
      );
    }
  }

  static Future<SelfAssignPageData> suppliers({
    required String mode,
    int page = 1,
    String search = '',
  }) async {
    const paths = {
      'cro-ro': '/api-crm/self-assign/suppliers',
      'cro': '/api-crm/self-assign/suppliers-cro',
      'ro': '/api-crm/self-assign/suppliers-ro-area',
      'revisit': '/api-crm/self-assign/suppliers-revisit',
    };
    final dio = await GeuApiClient.instance;
    final response = await dio.get(
      paths[mode]!,
      queryParameters: {
        'page': page,
        'limit': 20,
        if (search.isNotEmpty) 'search': search,
      },
    );
    final body = response.data;
    final data = GeuApiClient.unwrapData(body);
    if (response.statusCode != 200 || data is! Map)
      throw Exception(
        (body is Map ? body['message'] : null) ??
            'Daftar supplier tidak dapat dimuat.',
      );
    final pageData = Map<String, dynamic>.from(data);
    final pagination = pageData['pagination'] as Map?;
    return SelfAssignPageData(
      suppliers: (pageData['suppliers'] as List? ?? [])
          .whereType<Map>()
          .map((e) => SelfAssignSupplier.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      hasNext: pagination?['has_next'] == true,
    );
  }

  static Future<void> claim({
    required int supplierId,
    required String role,
  }) async {
    final dio = await GeuApiClient.instance;
    final response = await dio.post(
      '/api-crm/self-assign/claim',
      data: {'supplier_id': supplierId, 'role': role},
    );
    final body = response.data;
    if (response.statusCode != 200 ||
        (body is Map && body['status'] == 'error'))
      throw Exception(
        (body is Map ? body['message'] : null) ??
            'Supplier sudah diklaim oleh pengguna lain.',
      );
  }
}
