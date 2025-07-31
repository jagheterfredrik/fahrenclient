import 'package:flutter/material.dart';
import 'package:fahrenclient/shared_preferences_helper.dart';

class DeviceState extends ChangeNotifier {
  String? _selectedDeviceId;
  String? _selectedDeviceName;
  Set<String> _pairedDeviceIds = {};

  String? get selectedDeviceId => _selectedDeviceId;
  String? get selectedDeviceName => _selectedDeviceName;

  bool get isDeviceSelected => _selectedDeviceId != null;
  Set<String> get pairedDeviceIds => _pairedDeviceIds;

  Future<void> loadSelectedDevice() async {
    final deviceData = await SharedPreferencesHelper.loadSelectedDevice();
    _selectedDeviceId = deviceData['id'];
    _selectedDeviceName = deviceData['name'];
    await _loadPairedDevices();
    notifyListeners();
  }

  Future<void> _loadPairedDevices() async {
    final List<String> pairedList = await SharedPreferencesHelper.loadPairedDevices();
    _pairedDeviceIds = pairedList.toSet();
  }

  bool isDevicePaired(String deviceId) {
    return _pairedDeviceIds.contains(deviceId);
  }

  Future<void> setSelectedDevice(String deviceId, String deviceName) async {
    _selectedDeviceId = deviceId;
    _selectedDeviceName = deviceName;
    await SharedPreferencesHelper.saveSelectedDevice(deviceId, deviceName);
    _pairedDeviceIds.add(deviceId); // Add to paired devices when selected
    notifyListeners();
  }

  Future<void> clearSelectedDevice() async {
    _selectedDeviceId = null;
    _selectedDeviceName = null;
    await SharedPreferencesHelper.clearSelectedDevice();
    notifyListeners();
  }
}