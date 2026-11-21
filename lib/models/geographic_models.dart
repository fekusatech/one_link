// Geographic Models for cascading dropdowns

// Province Model
class Province {
  final int id;
  final String name;

  Province({required this.id, required this.name});

  factory Province.fromJson(Map<String, dynamic> json) {
    return Province(
      id: int.parse(json['id'].toString()),
      name: json['name'] ?? '',
    );
  }
}

class City {
  final int id;
  final String name;
  final int? idProvinsi;
  final int provinceId;

  City({
    required this.id,
    required this.name,
    this.idProvinsi,
    int? provinceId,
  }) : provinceId = provinceId ?? idProvinsi ?? 0;

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      idProvinsi: json['id_provinsi'] == null
          ? null
          : int.tryParse(json['id_provinsi'].toString()),
    );
  }
}

class District {
  final int id;
  final String name;
  final int? idKota;
  final int cityId;

  District({
    required this.id,
    required this.name,
    this.idKota,
    int? cityId,
  }) : cityId = cityId ?? idKota ?? 0;

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      id: int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      idKota: json['id_kota'] == null
          ? null
          : int.tryParse(json['id_kota'].toString()),
    );
  }
}

class Village {
  final int id;
  final String name;
  final int? idKecamatan;
  final int districtId;

  Village({
    required this.id,
    required this.name,
    this.idKecamatan,
    int? districtId,
  }) : districtId = districtId ?? idKecamatan ?? 0;

  factory Village.fromJson(Map<String, dynamic> json) {
    return Village(
      id: int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      idKecamatan: json['id_kecamatan'] == null
          ? null
          : int.tryParse(json['id_kecamatan'].toString()),
    );
  }
}
