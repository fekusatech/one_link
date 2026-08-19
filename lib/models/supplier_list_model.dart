// Supplier List Response Model
class SupplierListResponse {
  final List<SupplierListItem> data;
  final int total;
  final int currentPage;
  final int lastPage;

  SupplierListResponse({
    required this.data,
    required this.total,
    required this.currentPage,
    required this.lastPage,
  });

  factory SupplierListResponse.fromJson(Map<String, dynamic> json) {
    // Handle direct array response (non-paginated)
    if (json['data'] is List) {
      final supplierList = (json['data'] as List)
          .map((item) => SupplierListItem.fromJson(item))
          .toList();

      return SupplierListResponse(
        data: supplierList,
        total: supplierList.length,
        currentPage: 1,
        lastPage: 1,
      );
    }

    // Handle paginated response (if API structure changes)
    return SupplierListResponse(
      data:
          (json['data'] as List?)
              ?.map((item) => SupplierListItem.fromJson(item))
              .toList() ??
          [],
      total: int.tryParse(json['total']?.toString() ?? '0') ?? 0,
      currentPage: int.tryParse(json['current_page']?.toString() ?? '1') ?? 1,
      lastPage: int.tryParse(json['last_page']?.toString() ?? '1') ?? 1,
    );
  }
}

// Supplier List Item Model
class SupplierListItem {
  final String id;
  final String? kode;
  final String name;
  final String? phone;
  final String? email;
  final String? alamat;
  final String? gps;
  final String jenis;
  final String? jenisName;
  final String? kategoriName;
  final String? provinsiName;
  final String? kotaName;
  final String? kecamatanName;
  final String? desaName;
  final String? karyawan;
  final String? jabatan;
  final String? jenisUco;
  final double? price;
  final String? priceSatuanName;
  final String? namaRek;
  final String? nomorRek;
  final String? bankRekName;
  final String? siklus;
  final int? poin;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SupplierListItem({
    required this.id,
    this.kode,
    required this.name,
    this.phone,
    this.email,
    this.alamat,
    this.gps,
    required this.jenis,
    this.jenisName,
    this.kategoriName,
    this.provinsiName,
    this.kotaName,
    this.kecamatanName,
    this.desaName,
    this.karyawan,
    this.jabatan,
    this.jenisUco,
    this.price,
    this.priceSatuanName,
    this.namaRek,
    this.nomorRek,
    this.bankRekName,
    this.siklus,
    this.poin,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory SupplierListItem.fromJson(Map<String, dynamic> json) {
    return SupplierListItem(
      id: json['id']?.toString() ?? '',
      kode: json['kode_poo']?.toString() ?? json['kode']?.toString(),
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      alamat: json['alamat']?.toString(),
      gps: json['gps']?.toString(),
      jenis: json['jenis']?.toString() ?? '',
      jenisName: json['jenis_name']?.toString(),
      kategoriName: json['kategori_name']?.toString(),
      provinsiName: json['provinsi_name']?.toString(),
      kotaName: json['kota_name']?.toString(),
      kecamatanName: json['kecamatan_name']?.toString(),
      desaName: json['desa_name']?.toString(),
      karyawan: json['karyawan']?.toString(),
      jabatan: json['jabatan']?.toString(),
      jenisUco: json['jenis_uco']?.toString(),
      price: json['price'] != null
          ? double.tryParse(json['price'].toString())
          : null,
      priceSatuanName: json['price_satuan_name']?.toString(),
      namaRek: json['nama_rek']?.toString(),
      nomorRek: json['nomor_rek']?.toString(),
      bankRekName: json['bank_rek_name']?.toString(),
      siklus: json['siklus']?.toString(),
      poin: json['poin'] != null ? int.tryParse(json['poin'].toString()) : null,
      status: json['status']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kode': kode,
      'name': name,
      'phone': phone,
      'email': email,
      'alamat': alamat,
      'gps': gps,
      'jenis': jenis,
      'jenis_name': jenisName,
      'kategori_name': kategoriName,
      'provinsi_name': provinsiName,
      'kota_name': kotaName,
      'kecamatan_name': kecamatanName,
      'desa_name': desaName,
      'karyawan': karyawan,
      'jabatan': jabatan,
      'jenis_uco': jenisUco,
      'price': price,
      'price_satuan_name': priceSatuanName,
      'nama_rek': namaRek,
      'nomor_rek': nomorRek,
      'bank_rek_name': bankRekName,
      'siklus': siklus,
      'poin': poin,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
