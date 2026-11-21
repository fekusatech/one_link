bool _isccFlag(dynamic value) {
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == '1' ||
      normalized == 'true' ||
      normalized == 'yes' ||
      normalized == 'ya';
}

class Supplier {
  final int? id;
  final String? kodePoo;
  final String jenis;
  final int? picId;
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
  final int? bankRekId;
  final String? siklus;
  final int? poin;
  final int? statusId;
  final int? gudangTerdekatId;
  final bool isIsccCertified;
  final int? active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Supplier({
    this.id,
    this.kodePoo,
    required this.jenis,
    this.picId,
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
    this.bankRekId,
    this.siklus,
    this.poin,
    this.statusId,
    this.gudangTerdekatId,
    this.isIsccCertified = false,
    this.active,
    this.createdAt,
    this.updatedAt,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      kodePoo: json['kode_poo']?.toString(),
      jenis: json['jenis']?.toString() ?? '',
      picId: json['pic_id'] != null
          ? int.tryParse(json['pic_id'].toString())
          : null,
      name: json['name']?.toString() ?? '',
      karyawan: json['karyawan']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      jabatan: json['jabatan']?.toString() ?? '',
      kategoriId: json['kategori_id'] != null
          ? int.tryParse(json['kategori_id'].toString())
          : null,
      jenisUco: json['jenis_uco']?.toString(),
      price: json['price'] != null
          ? double.tryParse(json['price'].toString())
          : null,
      priceSatuanId: json['price_satuan'] != null
          ? int.tryParse(json['price_satuan'].toString())
          : null,
      provinsiId: json['provinsi_id'] != null
          ? int.tryParse(json['provinsi_id'].toString())
          : null,
      kotaId: json['kota_id'] != null
          ? int.tryParse(json['kota_id'].toString())
          : null,
      kecamatanId: json['kecamatan_id'] != null
          ? int.tryParse(json['kecamatan_id'].toString())
          : null,
      desaId: json['desa_id'] != null
          ? int.tryParse(json['desa_id'].toString())
          : null,
      alamat: json['alamat']?.toString(),
      gps: json['gps']?.toString(),
      namaRek: json['nama_rek']?.toString() ?? '',
      nomorRek: json['nomor_rek']?.toString() ?? '',
      bankRekId: json['bank_rek_id'] != null
          ? int.tryParse(json['bank_rek_id'].toString())
          : null,
      siklus: json['siklus']?.toString(),
      poin: json['poin'] != null ? int.tryParse(json['poin'].toString()) : null,
      statusId: json['status_id'] != null
          ? int.tryParse(json['status_id'].toString())
          : null,
      gudangTerdekatId: json['gudang_terdekat_id'] != null
          ? int.tryParse(json['gudang_terdekat_id'].toString())
          : null,
      isIsccCertified: _isccFlag(json['is_iscc_certified']),
      active: json['active'] != null
          ? int.tryParse(json['active'].toString())
          : null,
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
      'name': name,
      'phone': phone,
      'jabatan': jabatan,
      'karyawan': karyawan,
      'nama_rek': namaRek,
      'nomor_rek': nomorRek,
      'pic_id': picId,
      'kategori_id': kategoriId,
      'bank_rek_id': bankRekId,
      'provinsi_id': provinsiId,
      'kota_id': kotaId,
      'kecamatan_id': kecamatanId,
      'desa_id': desaId,
      'alamat': alamat,
      'gps': gps,
      'price': price,
      'price_satuan': priceSatuanId,
      'jenis_uco': jenisUco,
      'siklus': siklus,
      'poin': poin,
      'status_id': statusId,
      'gudang_terdekat_id': gudangTerdekatId,
      'is_iscc_certified': isIsccCertified ? 1 : 0,
    }..removeWhere((_, v) => v == null);
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'jenis': jenis,
      'name': name,
      'phone': phone,
      'jabatan': jabatan,
      'karyawan': karyawan,
      'nama_rek': namaRek,
      'nomor_rek': nomorRek,
      'pic_id': picId,
      'kategori_id': kategoriId,
      'bank_rek_id': bankRekId,
      'provinsi_id': provinsiId,
      'kota_id': kotaId,
      'kecamatan_id': kecamatanId,
      'desa_id': desaId,
      'alamat': alamat,
      'gps': gps,
      'price': price,
      'price_satuan': priceSatuanId,
      'jenis_uco': jenisUco,
      'siklus': siklus,
      'poin': poin,
      'status_id': statusId,
      'gudang_terdekat_id': gudangTerdekatId,
      'is_iscc_certified': isIsccCertified ? 1 : 0,
    }..removeWhere((_, v) => v == null);
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
