
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:fahrenclient/detailed_view_page.dart';
import 'package:fahrenclient/device_state.dart';
import 'package:provider/provider.dart';

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
  Timer? _scanTimer;

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

    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isScanning) {
        _stopScan();
      }
    });

    try {
      List<BleDevice> devices =
          await UniversalBle.getSystemDevices(withServices: ['ABCD']);
      if (mounted) {
        setState(() {
          _scannedDevices.addAll(devices);
        });
      }
      _scanSubscription = UniversalBle.scanStream.listen((scanResult) {
        if (!mounted) return;
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
            _scannedDevices[existingIndex].manufacturerDataList =
                scanResult.manufacturerDataList;
          }
        });
      });

      ScanFilter filter = ScanFilter(withServices: ['ABCD']);
      await UniversalBle.startScan(scanFilter: filter);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  // Stops the BLE scan.
  void _stopScan() async {
    _scanTimer?.cancel();
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
    _scanTimer?.cancel();
    _stopScan();
    super.dispose();
  }
  Widget _buildDeviceCard(
      BleDevice device, Future<void> Function(BleDevice) onTap) {
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
        onTap: () => onTap(
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
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceState = Provider.of<DeviceState>(context);
    final pairedDeviceIds = deviceState.pairedDeviceIds;

    // Separate devices into paired and unpaired lists
    final List<BleDevice> pairedDevices = _scannedDevices
        .where((device) => pairedDeviceIds.contains(device.deviceId))
        .toList();
    final List<BleDevice> unpairedDevices = _scannedDevices
        .where((device) => !pairedDeviceIds.contains(device.deviceId))
        .toList();

    // Sort both lists by device name
    pairedDevices.sort((a, b) =>
        _getDeviceDisplayName(a).compareTo(_getDeviceDisplayName(b)));
    unpairedDevices.sort((a, b) =>
        _getDeviceDisplayName(a).compareTo(_getDeviceDisplayName(b)));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Select Device',
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _scannedDevices.isEmpty && !_isScanning
                ? const Center(
                    child: Text(
                      'No devices found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView(
                    children: [
                      if (pairedDevices.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: Text(
                            'Paired Devices',
                            style: TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        ...pairedDevices.map((device) =>
                            _buildDeviceCard(device, _selectDevice)),
                      ],
                      if (unpairedDevices.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: Text(
                            'Available Devices',
                            style: TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        ...unpairedDevices.map((device) =>
                            _buildDeviceCard(device, _selectDevice)),
                      ],
                    ],
                  ),
          ),
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Scanning for devices...'),
                ],
              ),
            ),
          if (!_isScanning)
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 16.0),
              child: ElevatedButton.icon(
                onPressed: _startScan,
                label: const Text('Scan Again'),
                icon: const Icon(Icons.refresh, color: Colors.white),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  elevation: 5,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
                elevation: 5,
              ),
            ), // Closing ElevatedButton
          ),
        ],
      ),
    );
  }

  void _startDemoMode() {
    _stopScan();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DetailedViewPage(
          uuid: 'DEMO_UUID',
          deviceName: 'Demo Device',
          isDemoMode: true,
        ),
      ),
    );
  }
}
