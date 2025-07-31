
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:fahrenclient/detailed_view_page.dart';
import 'package:fahrenclient/battery_data.dart';
import 'package:fahrenclient/device_state.dart'; // Import DeviceState
import 'package:provider/provider.dart'; // Import provider

class DeviceSelectionPage extends StatefulWidget {
  final String? rememberedDeviceName;
  final String? rememberedDeviceId;

  const DeviceSelectionPage({
    super.key,
    this.rememberedDeviceName,
    this.rememberedDeviceId,
  });

  @override
  DeviceSelectionPageState createState() => DeviceSelectionPageState();
}

class DeviceSelectionPageState extends State<DeviceSelectionPage> {
  final List<BleDevice> _scannedDevices = [];
  bool _isScanning = false;
  StreamSubscription? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  // Converts a byte list to a hexadecimal string.
  String _bytesToHexString(Uint8List bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  // Gets the display name of a BLE device.
  String _getDeviceDisplayName(BleDevice device) {
    if (device.manufacturerDataList.isNotEmpty) {
      for (ManufacturerData manufacturerDataEntry
          in device.manufacturerDataList) {
        try {
          // Attempt to decode the manufacturer data as a UTF-8 string.
          String decoded = utf8.decode(manufacturerDataEntry.payload);
          if (decoded.isNotEmpty) {
            return decoded;
          }
        } catch (e) {
          // If decoding fails, display the raw hexadecimal data.
          return 'Invalid name: ${_bytesToHexString(manufacturerDataEntry.payload)}';
        }
      }
    }
    // If no manufacturer data is available, use the device name or a default value.
    return device.name != null && device.name!.isNotEmpty
        ? device.name!
        : 'Unknown Device (${device.deviceId})';
  }

  // Starts scanning for BLE devices.
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
          // Check if the device is already in the list.
          int existingIndex = _scannedDevices.indexWhere(
            (device) => device.deviceId == scanResult.deviceId,
          );
          if (existingIndex == -1) {
            // Add the new device to the list.
            _scannedDevices.add(scanResult);
          } else {
            // If the device is already in the list, update its manufacturer data.
            // _scannedDevices[existingIndex] = scanResult;
            _scannedDevices[existingIndex].manufacturerDataList = scanResult.manufacturerDataList;
          }
        });
      });

      ScanFilter filter = ScanFilter(withServices: ['ABCD']);
      await UniversalBle.startScan(scanFilter: filter);
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  // Stops the BLE scan.
  void _stopScan() async {
    if (_isScanning) {
      await UniversalBle.stopScan();
      _scanSubscription?.cancel();
      _scanSubscription = null;
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  // Saves the selected device and navigates to the detailed view.
  Future<void> _selectDevice(BleDevice device) async {
    _stopScan();
    // Navigate to the detailed view page.
    if (mounted) {
      // Ensure the widget is still in the tree.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DetailedViewPage(
            uuid: device.deviceId,
            deviceName: _getDeviceDisplayName(device),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceState = Provider.of<DeviceState>(context);
    final pairedDeviceIds = deviceState.pairedDeviceIds;

    // Sort devices: paired devices first, then by name
    final List<BleDevice> sortedDevices = List.from(_scannedDevices);
    sortedDevices.sort((a, b) {
      final bool aIsPaired = pairedDeviceIds.contains(a.deviceId);
      final bool bIsPaired = pairedDeviceIds.contains(b.deviceId);

      if (aIsPaired && !bIsPaired) {
        return -1; // a comes before b
      } else if (!aIsPaired && bIsPaired) {
        return 1; // b comes before a
      } else {
        // If both are paired or both are not paired, sort by name
        return _getDeviceDisplayName(a)
            .compareTo(_getDeviceDisplayName(b));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fahrenheat - Select Device',
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
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
                      !_isScanning
                ? const Center(
                    child: Text(
                      'No devices found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: sortedDevices.length,
                    itemBuilder: (BuildContext context, int index) {
                      final BleDevice device = sortedDevices[index];
                      final bool isPaired = pairedDeviceIds.contains(device.deviceId);
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
                          ),
                          borderRadius: BorderRadius.circular(10.0),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _getDeviceDisplayName(device),
                                    style: const TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                ),
                                if (isPaired)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
    // Static hex string representing demo battery data.
    const String demoHexString = '04983FF405C20147021706842E01F40182849F0B960B000000';
    
    // Convert the hex string to a byte list.
    Uint8List demoBytes = Uint8List.fromList(
      List.generate(demoHexString.length ~/ 2, (i) {
        return int.parse(demoHexString.substring(i * 2, i * 2 + 2), radix: 16);
      }),
    );
    
    // Create a BatteryData object from the demo bytes.
    final BatteryData demoBatteryData = BatteryData.fromBytes(demoBytes);
    
    // Navigate to the detailed view page with the demo data.
    _stopScan();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DetailedViewPage(
          uuid: 'DEMO_UUID',
          deviceName: 'Demo Device',
          demoBatteryData: demoBatteryData,
        ),
      ),
    );
  }
}
