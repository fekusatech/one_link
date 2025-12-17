class LoginResponse {
  final bool success;
  final String message;
  final String? redirect;
  final String? token;
  final Map<String, dynamic>? user;

  LoginResponse({
    required this.success,
    required this.message,
    this.redirect,
    this.token,
    this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      redirect: json['redirect'],
      token: json['token'],
      user: json['user'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'redirect': redirect,
      'token': token,
      'user': user,
    };
  }
}

class OtpResponse {
  final bool success;
  final String message;
  final String? token;
  final Map<String, dynamic>? user;

  OtpResponse({
    required this.success,
    required this.message,
    this.token,
    this.user,
  });

  factory OtpResponse.fromJson(Map<String, dynamic> json) {
    return OtpResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      token: json['token'],
      user: json['user'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'token': token,
      'user': user,
    };
  }
}
