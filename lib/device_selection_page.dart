
// This is the new onboarding page for device selection.
import 'dart:async';
import 'dart:typed_data'; // For Uint8List
import 'dart:convert'; // For utf8.decode
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:fahrenclient/shared_preferences_helper.dart'; // Import the new helper
import 'package:fahrenclient/detailed_view_page_v2.dart'; // Import DetailedViewPageV2
import 'package:fahrenclient/battery_data.dart'; // Import BatteryData

class DeviceSelectionPage extends StatefulWidget {
  final String? rememberedDeviceName;
  final String? rememberedDeviceId;

  const DeviceSelectionPage({
    super.key,
    this.rememberedDeviceName,
    this.rememberedDeviceId,
  });

  @override
  _DeviceSelectionPageState createState() => _DeviceSelectionPageState();
}

class _DeviceSelectionPageState extends State<DeviceSelectionPage> {
  // Changed _scannedUuids to store BleDevice objects
  final List<BleDevice> _scannedDevices = [];
  bool _isScanning = false;
  StreamSubscription? _scanSubscription;

  @override
  void initState() {
    super.initState();
    // Removed _startScan() from here. Scan will now be initiated by user gesture.
  }

  // Helper function to convert Uint8List to a hex string
  String _bytesToHexString(Uint8List bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  // Helper function to get the display name for a device
  String _getDeviceDisplayName(BleDevice device) {
    if (device.manufacturerDataList != null &&
        device.manufacturerDataList.isNotEmpty) {
      for (ManufacturerData manufacturerDataEntry
          in device.manufacturerDataList) {
        try {
          // Attempt to decode as UTF-8 first
          String decoded = utf8.decode(manufacturerDataEntry.payload);
          if (decoded.isNotEmpty) {
            return decoded;
          }
        } catch (e) {
          // Fallback to hex if UTF-8 decoding fails for this specific data
          return 'Invalid name: ${_bytesToHexString(manufacturerDataEntry.payload)}';
        }
      }
    }
    // Fallback to device name or unknown device if no valid manufacturer data is found
    return device.name != null && device.name!.isNotEmpty
        ? device.name!
        : 'Unknown Device (${device.deviceId})';
  }

  // Start scanning for Bluetooth devices
  void _startScan() async {
    setState(() {
      _isScanning = true;
      _scannedDevices.clear();
    });

    try {
      List<BleDevice> devices = await UniversalBle.getSystemDevices(withServices: ['ABCD']);
      _scannedDevices.addAll(devices);
      _scanSubscription = UniversalBle.scanStream.listen((scanResult) {
        setState(() {
          // Check if a device with the same deviceId already exists
          int existingIndex = _scannedDevices.indexWhere(
            (device) => device.deviceId == scanResult.deviceId,
          );
          if (existingIndex == -1) {
            // If not found, add the new device
            _scannedDevices.add(scanResult);
          } else {
            // If found, update the existing device (e.g., if RSSI or other properties change)
            // _scannedDevices[existingIndex] = scanResult;
            _scannedDevices[existingIndex].manufacturerDataList = scanResult.manufacturerDataList;
          }
        });
      });

      ScanFilter filter = ScanFilter(withServices: ['ABCD']);
      await UniversalBle.startScan(scanFilter: filter);
    } catch (e) {
      print('Bluetooth scan error: $e');
      setState(() {
        _isScanning = false;
      });
    }
  }

  // Stop scanning for Bluetooth devices
  void _stopScan() async {
    if (_isScanning) {
      await UniversalBle.stopScan();
      _scanSubscription?.cancel();
      _scanSubscription = null;
      setState(() {
        _isScanning = false;
      });
    }
  }

  // Saves the selected device ID and name to SharedPreferences and navigates to DetailedViewPage
  Future<void> _selectDevice(BleDevice device) async {
    _stopScan(); // Stop scanning once a device is selected
    await SharedPreferencesHelper.saveSelectedDevice(
      device.deviceId,
      _getDeviceDisplayName(device),
    );

    // Navigate to the DetailedViewPage, replacing the current route
    if (mounted) {
      // Ensure the widget is still mounted before navigation
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DetailedViewPageV2(
            uuid: device.deviceId,
            deviceName: _getDeviceDisplayName(device), // Pass the device name
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _stopScan(); // Ensure scan is stopped when widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fahrenheat - Select Device',
        ), // New title for selection page
        centerTitle: true,
        elevation: 0, // Remove shadow
      ),
      body: Column(
        // Use a Column to arrange elements vertically
        children: [
          Expanded(
            // Let the content take available space
            child: _isScanning && _scannedDevices.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Scanning for devices...'),
                      ],
                    ),
                  )
                : _scannedDevices.isEmpty &&
                      !_isScanning // Added ! _isScanning condition for initial state
                ? const Center(
                    child: Text(
                      'Tap "Start Scan" to start scanning.', // Updated message
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _scannedDevices.length,
                    itemBuilder: (BuildContext context, int index) {
                      final BleDevice device = _scannedDevices[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 16.0,
                        ),
                        elevation: 4.0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: InkWell(
                          onTap: () => _selectDevice(
                            device,
                          ), // Pass the BleDevice object
                          borderRadius: BorderRadius.circular(10.0),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              _getDeviceDisplayName(device),
                              style: const TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.w500,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              bottom: 24.0,
              top: 16.0,
            ), // Add padding for the button
            child: ElevatedButton.icon(
              onPressed: _isScanning
                  ? _stopScan
                  : _startScan, // Keep the stop functionality
              label: Text(
                _isScanning ? 'Stop Scan' : 'Start Scan', // Changed label
              ),
              icon: Icon(
                _isScanning
                    ? Icons.bluetooth_disabled
                    : Icons.bluetooth, // Changed icon
                color: Colors.white,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isScanning
                    ? Colors.redAccent
                    : Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
                elevation: 5, // Add some elevation
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: ElevatedButton.icon(
              onPressed: _startDemoMode,
              label: const Text('Demo Mode'),
              icon: const Icon(Icons.developer_mode, color: Colors.white),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
                elevation: 5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startDemoMode() {
    // Static hex string for demo data
    const String demoHexString = '04983FF405C20147021706842E01F40182849F0B960B000000';

    // Convert hex string to Uint8List
    Uint8List demoBytes = Uint8List.fromList(
      List.generate(demoHexString.length ~/ 2, (i) {
        return int.parse(demoHexString.substring(i * 2, i * 2 + 2), radix: 16);
      }),
    );

    // Create BatteryData object from demo bytes
    final BatteryData demoBatteryData = BatteryData.fromBytes(demoBytes);

    // Navigate to DetailedViewPage with demo data
    _stopScan(); // Stop scanning before navigating
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DetailedViewPageV2(
          uuid: 'DEMO_UUID', // Placeholder UUID for demo mode
          deviceName: 'Demo Device', // Name for demo mode
          demoBatteryData: demoBatteryData, // Pass the demo data
        ),
      ),
    );
  }
}
