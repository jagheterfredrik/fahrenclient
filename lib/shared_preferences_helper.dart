import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesHelper {
  static const String _kSelectedDeviceIdKey = 'selected_device_id';
  static const String _kSelectedDeviceNameKey = 'selected_device_name';
  static const String _kPairedDeviceIdsKey = 'paired_device_ids';

  static Future<void> saveSelectedDevice(String deviceId, String deviceName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedDeviceIdKey, deviceId);
    await prefs.setString(_kSelectedDeviceNameKey, deviceName);
    await _addPairedDevice(deviceId); // Mark as paired when selected
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

  static Future<void> _addPairedDevice(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> pairedDevices = prefs.getStringList(_kPairedDeviceIdsKey) ?? [];
    if (!pairedDevices.contains(deviceId)) {
      pairedDevices.add(deviceId);
      await prefs.setStringList(_kPairedDeviceIdsKey, pairedDevices);
    }
  }

  static Future<List<String>> loadPairedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kPairedDeviceIdsKey) ?? [];
  }

  static Future<void> removePairedDevice(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> pairedDevices = prefs.getStringList(_kPairedDeviceIdsKey) ?? [];
    pairedDevices.remove(deviceId);
    await prefs.setStringList(_kPairedDeviceIdsKey, pairedDevices);
  }
}