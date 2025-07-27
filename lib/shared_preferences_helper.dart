import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesHelper {
  static const String _kSelectedDeviceIdKey = 'selected_device_id';
  static const String _kSelectedDeviceNameKey = 'selected_device_name';

  static Future<void> saveSelectedDevice(String deviceId, String deviceName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedDeviceIdKey, deviceId);
    await prefs.setString(_kSelectedDeviceNameKey, deviceName);
  }

  static Future<Map<String, String?>> loadSelectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString(_kSelectedDeviceIdKey);
    final deviceName = prefs.getString(_kSelectedDeviceNameKey);
    return {
      'id': deviceId,
      'name': deviceName,
    };
  }

  static Future<void> clearSelectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSelectedDeviceIdKey);
    await prefs.remove(_kSelectedDeviceNameKey);
  }
}