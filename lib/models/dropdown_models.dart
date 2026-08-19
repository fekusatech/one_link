// Supplier Type Model
class JenisSupplier {
  final int id;
  final String name;
  final String? prefix;

  JenisSupplier({required this.id, required this.name, this.prefix});

  factory JenisSupplier.fromJson(Map<String, dynamic> json) {
    return JenisSupplier(
      id: int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      prefix: json['prefix'],
    );
  }
}

// Supplier Category Model
class KategoriSupplier {
  final int id;
  final String name;
  final String? keterangan;

  KategoriSupplier({required this.id, required this.name, this.keterangan});

  factory KategoriSupplier.fromJson(Map<String, dynamic> json) {
    return KategoriSupplier(
      id: int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      keterangan: json['keterangan'],
    );
  }
}

// Employee Model
class Employee {
  final int id;
  final String name;
  final String? position;
  final String? jabatan;

  Employee({required this.id, required this.name, this.position, this.jabatan});

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      position: json['position'],
      jabatan: json['jabatan'],
    );
  }
}

// Bank Model
class Bank {
  final int id;
  final String namaBank;
  final String kodeBank;

  Bank({required this.id, required this.namaBank, required this.kodeBank});

  factory Bank.fromJson(Map<String, dynamic> json) {
    return Bank(
      id: int.parse(json['id'].toString()),
      namaBank: json['nama_bank'] ?? '',
      kodeBank: json['kode_bank'] ?? '',
    );
  }
}

// Unit Model
class Satuan {
  final int id;
  final String name;
  final String? short;

  Satuan({required this.id, required this.name, this.short});

  factory Satuan.fromJson(Map<String, dynamic> json) {
    return Satuan(
      id: int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      short: json['short'],
    );
  }
}
