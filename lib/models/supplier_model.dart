// Supplier Model
class Supplier {
  final int? id;
  final String? kodePoo;
  final String jenis;
  final int picId;
  final String name;
  final String karyawan;
  final String phone;
  final String jabatan;
  final int? kategoriId;
  final String? jenisUco;
  final double? price;
  final int? priceSatuanId;
  final int? provinsiId;
  final int? kotaId;
  final int? kecamatanId;
  final int? desaId;
  final String? alamat;
  final String? gps;
  final String namaRek;
  final String nomorRek;
  final int bankRekId;
  final String? siklus;
  final int? poin;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Supplier({
    this.id,
    this.kodePoo,
    required this.jenis,
    required this.picId,
    required this.name,
    required this.karyawan,
    required this.phone,
    required this.jabatan,
    this.kategoriId,
    this.jenisUco,
    this.price,
    this.priceSatuanId,
    this.provinsiId,
    this.kotaId,
    this.kecamatanId,
    this.desaId,
    this.alamat,
    this.gps,
    required this.namaRek,
    required this.nomorRek,
    required this.bankRekId,
    this.siklus,
    this.poin,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] != null ? int.parse(json['id'].toString()) : null,
      kodePoo: json['kode_poo'],
      jenis: json['jenis'] ?? '',
      picId: int.parse(json['pic'].toString()),
      name: json['name'] ?? '',
      karyawan: json['karyawan'] ?? '',
      phone: json['phone'] ?? '',
      jabatan: json['jabatan'] ?? '',
      kategoriId: json['kategori'] != null
          ? int.parse(json['kategori'].toString())
          : null,
      jenisUco: json['jenis_uco'],
      price: json['price'] != null
          ? double.tryParse(json['price'].toString())
          : null,
      priceSatuanId: json['price_satuan'] != null
          ? int.parse(json['price_satuan'].toString())
          : null,
      provinsiId: json['provinsi_id'] != null
          ? int.parse(json['provinsi_id'].toString())
          : null,
      kotaId: json['kota_id'] != null
          ? int.parse(json['kota_id'].toString())
          : null,
      kecamatanId: json['kecamatan_id'] != null
          ? int.parse(json['kecamatan_id'].toString())
          : null,
      desaId: json['desa_id'] != null
          ? int.parse(json['desa_id'].toString())
          : null,
      alamat: json['alamat'],
      gps: json['gps'],
      namaRek: json['nama_rek'] ?? '',
      nomorRek: json['nomor_rek'] ?? '',
      bankRekId: int.parse(json['bank_rek'].toString()),
      siklus: json['siklus'],
      poin: json['poin'] != null ? int.parse(json['poin'].toString()) : null,
      status: json['status'],
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
      'jenis': jenis,
      'pic': picId,
      'name': name,
      'karyawan': karyawan,
      'phone': phone,
      'jabatan': jabatan,
      'kategori': kategoriId,
      'jenis_uco': jenisUco,
      'price': price?.toString(),
      'price_satuan': priceSatuanId,
      'provinsi_id': provinsiId,
      'kota_id': kotaId,
      'kecamatan_id': kecamatanId,
      'desa_id': desaId,
      'alamat': alamat,
      'gps': gps,
      'nama_rek': namaRek,
      'nomor_rek': nomorRek,
      'bank_rek': bankRekId,
      'siklus': siklus,
      'poin': poin,
    };
  }
}

// Supplier List Response Model
class SupplierListResponse {
  final List<Supplier> suppliers;
  final int total;
  final int currentPage;
  final int lastPage;

  SupplierListResponse({
    required this.suppliers,
    required this.total,
    required this.currentPage,
    required this.lastPage,
  });

  factory SupplierListResponse.fromJson(Map<String, dynamic> json) {
    return SupplierListResponse(
      suppliers: (json['data'] as List? ?? [])
          .map((item) => Supplier.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: int.parse(json['total'].toString()),
      currentPage: int.parse(json['current_page'].toString()),
      lastPage: int.parse(json['last_page'].toString()),
    );
  }
}
