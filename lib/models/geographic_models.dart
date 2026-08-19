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

// City Model
class City {
  final int id;
  final String name;
  final int idProvinsi;
  final int provinceId; // Add this for compatibility

  City({
    required this.id,
    required this.name,
    required this.idProvinsi,
    int? provinceId,
  }) : provinceId = provinceId ?? idProvinsi;

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      idProvinsi: int.parse(json['id_provinsi'].toString()),
    );
  }
}

// District Model
class District {
  final int id;
  final String name;
  final int idKota;
  final int cityId; // Add this for compatibility

  District({
    required this.id,
    required this.name,
    required this.idKota,
    int? cityId,
  }) : cityId = cityId ?? idKota;

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      id: int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      idKota: int.parse(json['id_kota'].toString()),
    );
  }
}

// Village Model
class Village {
  final int id;
  final String name;
  final int idKecamatan;
  final int districtId; // Add this for compatibility

  Village({
    required this.id,
    required this.name,
    required this.idKecamatan,
    int? districtId,
  }) : districtId = districtId ?? idKecamatan;

  factory Village.fromJson(Map<String, dynamic> json) {
    return Village(
      id: int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      idKecamatan: int.parse(json['id_kecamatan'].toString()),
    );
  }
}
