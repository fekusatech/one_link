import 'package:shared_preferences/shared_preferences.dart';

class VisitGpsModeService {
  static const _key = 'geu_visit_manual_offline';
  static Future<bool> isManualOffline() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;
  static Future<void> setManualOffline(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_key, value);
}
