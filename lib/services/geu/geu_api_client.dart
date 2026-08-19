import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

/// Shared Dio client for the new Go REST API (apipi.greenenergiutama.co.id).
/// Auth is httpOnly JWT cookies (auth_token/refresh_token), not Bearer —
/// see doc.md. Session cookies persist to disk so login survives app restart.
class GeuApiClient {
  static const String baseUrl = 'https://apipi.greenenergiutama.co.id';

  static Dio? _dio;
  static PersistCookieJar? _cookieJar;
  static Future<bool>? _refreshFuture;

  static Future<Dio> get instance async {
    final existing = _dio;
    if (existing != null) return existing;

    final dir = await getApplicationDocumentsDirectory();
    final cookieJar = PersistCookieJar(
      storage: FileStorage('${dir.path}/.geu_cookies/'),
    );
    _cookieJar = cookieJar;

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        headers: {'Content-Type': 'application/json'},
      ),
    );
    dio.interceptors.add(CookieManager(cookieJar));
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          final isAuthCall = error.requestOptions.path.contains('/api-auth/');
          if (error.response?.statusCode == 401 && !isAuthCall) {
            final refreshed = await _refresh(dio);
            if (refreshed) {
              try {
                final retryResponse = await dio.fetch(error.requestOptions);
                return handler.resolve(retryResponse);
              } catch (_) {
                // fall through to the session-expired response below
              }
            }
            return handler.resolve(
              Response(
                requestOptions: error.requestOptions,
                statusCode: 401,
                data: {
                  'status': 'error',
                  'message':
                      'Sesi Canvassing berakhir. Silakan logout lalu login ulang.',
                },
              ),
            );
          }

          // The backend already replies with {status, code, message} on
          // failure (see doc.md) — resolve with it instead of letting Dio
          // throw, so callers' existing _unwrap gives a clean message
          // instead of a raw DioException dump.
          final response = error.response;
          if (response != null) return handler.resolve(response);

          return handler.resolve(
            Response(
              requestOptions: error.requestOptions,
              statusCode: 0,
              data: {
                'status': 'error',
                'message':
                    'Tidak ada koneksi ke server. Periksa internet Anda.',
              },
            ),
          );
        },
      ),
    );

    _dio = dio;
    return dio;
  }

  static Future<bool> _refresh(Dio dio) {
    return _refreshFuture ??= dio
        .post('/api-auth/refresh')
        .then((res) => res.statusCode == 200)
        .catchError((_) => false)
        .whenComplete(() => _refreshFuture = null);
  }

  /// Wipe the session (logout).
  static Future<void> clearSession() async {
    await _cookieJar?.deleteAll();
  }
}
