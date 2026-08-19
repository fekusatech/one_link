// Supplier Detail Model - Extended model for detailed API response
class SupplierDetail {
  final String id;
  final String kode;
  final String name;
  final String jenis;
  final String jenisName;
  final String kategoriName;
  final String provinsiName;
  final String kotaName;
  final String? kecamatanName;
  final String? desaName;
  final String? alamat;
  final String? phone;
  final String? karyawan;
  final String? jabatan;
  final String? jenisUco;
  final double? price;
  final String? priceSatuanName;
  final String? gps;
  final String? namaRek;
  final String? nomorRek;
  final String? bankRekName;
  final String? siklus;
  final int? poin;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SupplierDetail({
    required this.id,
    required this.kode,
    required this.name,
    required this.jenis,
    required this.jenisName,
    required this.kategoriName,
    required this.provinsiName,
    required this.kotaName,
    this.kecamatanName,
    this.desaName,
    this.alamat,
    this.phone,
    this.karyawan,
    this.jabatan,
    this.jenisUco,
    this.price,
    this.priceSatuanName,
    this.gps,
    this.namaRek,
    this.nomorRek,
    this.bankRekName,
    this.siklus,
    this.poin,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory SupplierDetail.fromJson(Map<String, dynamic> json) {
    return SupplierDetail(
      id: json['id']?.toString() ?? '',
      kode: json['kode']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      jenis: json['jenis']?.toString() ?? '',
      jenisName: json['jenis_name']?.toString() ?? '',
      kategoriName: json['kategori_name']?.toString() ?? '',
      provinsiName: json['provinsi_name']?.toString() ?? '',
      kotaName: json['kota_name']?.toString() ?? '',
      kecamatanName: json['kecamatan_name']?.toString(),
      desaName: json['desa_name']?.toString(),
      alamat: json['alamat']?.toString(),
      phone: json['phone']?.toString(),
      karyawan: json['karyawan']?.toString(),
      jabatan: json['jabatan']?.toString(),
      jenisUco: json['jenis_uco']?.toString(),
      price: json['price'] != null
          ? double.tryParse(json['price'].toString())
          : null,
      priceSatuanName: json['price_satuan_name']?.toString(),
      gps: json['gps']?.toString(),
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
      'jenis': jenis,
      'jenis_name': jenisName,
      'kategori_name': kategoriName,
      'provinsi_name': provinsiName,
      'kota_name': kotaName,
      'kecamatan_name': kecamatanName,
      'desa_name': desaName,
      'alamat': alamat,
      'phone': phone,
      'karyawan': karyawan,
      'jabatan': jabatan,
      'jenis_uco': jenisUco,
      'price': price,
      'price_satuan_name': priceSatuanName,
      'gps': gps,
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
