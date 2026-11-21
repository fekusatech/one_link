// Base API Response Model
class ApiResponse<T> {
  final bool status;
  final String message;
  final T? data;
  final Map<String, dynamic>? errors;

  ApiResponse({
    required this.status,
    required this.message,
    this.data,
    this.errors,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    final rawStatus = json['status'];
    final ok = rawStatus is bool
        ? rawStatus
        : rawStatus.toString().toLowerCase() == 'success';

    return ApiResponse<T>(
      status: ok,
      message: json['message']?.toString() ?? '',
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'],
      errors: json['errors'] is Map<String, dynamic> ? json['errors'] : null,
    );
  }
}
