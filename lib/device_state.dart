import 'package:flutter/material.dart';
import 'package:fahrenclient/shared_preferences_helper.dart';

class DeviceState extends ChangeNotifier {
  String? _selectedDeviceId;
  String? _selectedDeviceName;

  String? get selectedDeviceId => _selectedDeviceId;
  String? get selectedDeviceName => _selectedDeviceName;

  bool get isDeviceSelected => _selectedDeviceId != null;

  Future<void> loadSelectedDevice() async {
    final deviceData = await SharedPreferencesHelper.loadSelectedDevice();
    _selectedDeviceId = deviceData['id'];
    _selectedDeviceName = deviceData['name'];
    notifyListeners();
  }

  Future<void> setSelectedDevice(String deviceId, String deviceName) async {
    _selectedDeviceId = deviceId;
    _selectedDeviceName = deviceName;
    await SharedPreferencesHelper.saveSelectedDevice(deviceId, deviceName);
    notifyListeners();
  }

  Future<void> clearSelectedDevice() async {
    _selectedDeviceId = null;
    _selectedDeviceName = null;
    await SharedPreferencesHelper.clearSelectedDevice();
    notifyListeners();
  }
}