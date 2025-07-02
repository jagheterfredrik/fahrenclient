import 'dart:async';
import 'dart:convert';

import 'package:fahrenclient/battery_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import provider
import 'package:fahrenclient/device_state.dart'; // Import DeviceState
import 'package:universal_ble/universal_ble.dart';

class DetailedViewPage extends StatefulWidget {
  final String uuid; // The UUID to display
  final String? deviceName; // New: Optional device name

  const DetailedViewPage({super.key, required this.uuid, this.deviceName});

  @override
  _DetailedViewPageState createState() => _DetailedViewPageState();
}

class _DetailedViewPageState extends State<DetailedViewPage> {
  bool _isConnected = false;
  bool _isLoadingCharacteristic = false;
  bool? _isHeatingEnabled;
  String? _errorMessage;
  bool _isWritingHeatingCharacteristic = false; // New state for heating button loading
  StreamSubscription? _scanSubscription; // Add a subscription for scan stream
  StreamSubscription? _batteryDataSubscription; // Subscription for battery data
  Completer<void>?
  _deviceFoundCompleter; // Completer to signal when device is found
  BatteryData? _batteryData; // To store the parsed battery data

  // Define the service and characteristic UUIDs
  final String _serviceUuid = 'ABCD';
  final String _heatingCharacteristicUuid =
      'DEAD'; // Characteristic for heating enabled (0 or 1)
  final String _manufacturerNameCharacteristicUuid =
      'F00D'; // New characteristic for manufacturer name
  final String _batteryDataCharacteristicUuid =
      'BABE'; // Characteristic for battery data notifications

  late TextEditingController
  _nameController; // Controller for the editable name field

  @override
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.deviceName,
    ); // Initialize with passed device name
    _connectAndReadCharacteristic();

    // Listen to connection stream to update status dynamically
    UniversalBle.connectionStream(widget.uuid).listen((bool isConnected) {
      debugPrint('Is device ${widget.uuid} connected?: $isConnected');
      if (!mounted) return;
      setState(() {
        _isConnected = isConnected;
        if (!isConnected) {
          _batteryData = null; // Clear battery data if disconnected
        }
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose(); // Dispose the controller
    _disconnect();
    _batteryDataSubscription?.cancel(); // Cancel battery data subscription
    UniversalBle.onValueChange = null; // Clear the callback when disposing
    super.dispose();
  }

  // Helper to stop any ongoing scan
  void _stopScan() async {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    if (_deviceFoundCompleter != null && !_deviceFoundCompleter!.isCompleted) {
      _deviceFoundCompleter!.complete(); // Complete if not already completed
    }
    await UniversalBle.stopScan();
  }

  // Connects to the device and reads the characteristic
  Future<void> _connectAndReadCharacteristic() async {
    if (!mounted) return;

    setState(() {
      _isLoadingCharacteristic = true;
      _errorMessage = null;
    });

    try {
      // For iOS, perform a scan before connecting to a known device
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        print('iOS detected: Starting scan for known device ${widget.uuid}');
        BleDevice? foundDevice;
        _stopScan(); // Ensure no previous scan is running
        _deviceFoundCompleter = Completer<void>(); // Initialize completer

        _scanSubscription = UniversalBle.scanStream.listen((scanResult) {
          if (scanResult.deviceId == widget.uuid) {
            foundDevice = scanResult;
            _stopScan(); // Stop scan once device is found
            print('Found device ${widget.uuid} during scan.');
            if (!_deviceFoundCompleter!.isCompleted) {
              _deviceFoundCompleter!.complete(); // Signal that device is found
            }
          }
        });

        await UniversalBle.startScan(
          scanFilter: ScanFilter(withServices: [_serviceUuid]),
        );

        // Wait for the device to be found or timeout
        await _deviceFoundCompleter!.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('Scan timed out after 10 seconds.');
            return; // Do nothing on timeout, foundDevice will remain null
          },
        );

        _stopScan(); // Ensure scan is stopped after finding device or timeout

        if (foundDevice == null) {
          throw Exception(
            'Device ${widget.deviceName ?? widget.uuid} not found during scan. Please ensure it is advertising.',
          );
        }
      }

      // Attempt to connect to the device
      await UniversalBle.connect(widget.uuid);
      if (!mounted) return;
      setState(() {
        _isConnected = true;
      });

      await UniversalBle.pair(
        widget.uuid,
        pairingCommand: BleCommand(
          service: _serviceUuid,
          characteristic: _heatingCharacteristicUuid,
        ),
      );

      // Read the original characteristic (1235)
      final Uint8List value = await UniversalBle.read(
        widget.uuid,
        _serviceUuid,
        _heatingCharacteristicUuid,
      );

      // // Read the manufacturer name characteristic (1236)
      final Uint8List manufacturerNameValue = await UniversalBle.read(
        widget.uuid,
        _serviceUuid,
        _manufacturerNameCharacteristicUuid,
      );

      if (!mounted) return;
      setState(() {
        _isHeatingEnabled = value.isNotEmpty && value[0] == 0x01;
        _nameController.text = utf8.decode(
          manufacturerNameValue,
        ); // Update name controller with read value
        _isLoadingCharacteristic = false;
      });

      // Subscribe to battery data characteristic after successful connection
      _subscribeToBatteryData();
    } catch (e) {
      print('Error connecting or reading characteristic: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: Could not connect or read characteristic. ($e)';
        _isLoadingCharacteristic = false;
        _isConnected = false;
      });
    }
  }

  // Function to subscribe to battery data characteristic
  Future<void> _subscribeToBatteryData() async {
    try {
      await UniversalBle.subscribeNotifications(
        widget.uuid,
        _serviceUuid,
        _batteryDataCharacteristicUuid,
      );

      UniversalBle.onValueChange = _handleValueChange;
      print('Subscribed to battery data characteristic.');
    } catch (e) {
      print('Error subscribing to battery data: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error subscribing to battery data: $e';
      });
    }
  }

  // Callback function to handle characteristic value changes
  void _handleValueChange(
    String deviceId,
    String characteristicId,
    Uint8List value,
  ) {
    // print("Got data! $deviceId $characteristicId");
    if (deviceId == widget.uuid &&
        BleUuidParser.compareStrings(
          characteristicId,
          _batteryDataCharacteristicUuid,
        )) {
      setState(() {
        _batteryData = BatteryData.fromBytes(value);
      });
    }
  }

  // Disconnects from the device
  Future<void> _disconnect() async {
    try {
      await UniversalBle.disconnect(widget.uuid);
      if (!mounted) return; // Check mounted before calling setState
      setState(() {
        _isConnected = false;
        _batteryData = null; // Clear battery data on disconnect
      });
    } catch (e) {
      print('Error disconnecting: $e');
    }
  }

  // Function to write the new manufacturer name to characteristic 0x1236
  Future<void> _writeManufacturerName(String newName) async {
    if (!_isConnected) {
      setState(() {
        _errorMessage = 'Error: Not connected to device.';
      });
      return;
    }
    try {
      await UniversalBle.write(
        widget.uuid,
        _serviceUuid,
        _manufacturerNameCharacteristicUuid,
        Uint8List.fromList(utf8.encode(newName)),
      );
      if (!mounted) return;
      setState(() {
        _errorMessage = null; // Clear any previous error message
      });
      // Store the new name using DeviceState
      Provider.of<DeviceState>(
        context,
        listen: false,
      ).setSelectedDevice(widget.uuid, newName);
    } catch (e) {
      print('Error writing manufacturer name: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error writing name: $e';
      });
    }
  }

  // Function to write the heating characteristic (0 or 1)
  Future<void> _writeHeatingCharacteristic(bool enableHeating) async {
    if (!_isConnected) {
      setState(() {
        _errorMessage = 'Error: Not connected to device.';
      });
      return;
    }
    try {
      final Uint8List valueToWrite = Uint8List.fromList([
        enableHeating ? 0x01 : 0x00,
      ]);
      await UniversalBle.write(
        widget.uuid,
        _serviceUuid,
        _heatingCharacteristicUuid,
        valueToWrite,
      );
      if (!mounted) return;
      setState(() {
        _isHeatingEnabled = enableHeating;
        _errorMessage = null; // Clear any previous error message
      });
    } catch (e) {
      print('Error writing heating characteristic: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error writing heating status: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple, // Set AppBar background color
        // Use deviceName for the AppBar title
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Device Name',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                onEditingComplete: () =>
                    _writeManufacturerName(_nameController.text),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          Icon(
            _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: _isConnected ? Colors.green : Colors.redAccent,
            size: 24.0,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Display connection and characteristic status
              _isLoadingCharacteristic
                  ? const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Connecting...', textAlign: TextAlign.center),
                      ],
                    )
                  : _errorMessage != null
                  ? Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    )
                  : Column(
                      children: [
                        if (_isConnected)
                          Column(
                            children: [
                               Switch(
                                value: _isHeatingEnabled!,
                                onChanged: (bool newValue) {
                                  _writeHeatingCharacteristic(newValue);
                                },
                                activeColor:
                                    _batteryData?.batteryHeatingActive == true
                                    ? Colors.green
                                    : Colors.grey,
                                inactiveThumbColor: Colors.red,
                                inactiveTrackColor:
                                    _batteryData?.batteryHeatingActive == true
                                    ? Colors.green.withOpacity(0.5)
                                    : Colors.redAccent.withOpacity(0.5),
                              ),
                              ElevatedButton(
                                onPressed: _isWritingHeatingCharacteristic ||
                                        _isLoadingCharacteristic
                                    ? null
                                    : () => _writeHeatingCharacteristic(
                                        !(_isHeatingEnabled ?? false)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isHeatingEnabled == true
                                      ? Colors.green
                                      : Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  textStyle: const TextStyle(fontSize: 16),
                                ),
                                child: _isWritingHeatingCharacteristic
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _isHeatingEnabled == true
                                            ? 'Heating Enabled'
                                            : 'Heating Disabled',
                                      ),
                              ),
                              if (_errorMessage != null &&
                                  _errorMessage!.contains('heating status'))
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                        color: Colors.red, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                            ],
                          )
                        else
                          // Display message if disconnected
                          ...[
                            const Text(
                              'Device disconnected. Heating status unavailable.',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12.0),
                            ElevatedButton.icon(
                              onPressed: _isLoadingCharacteristic
                                  ? null
                                  : _connectAndReadCharacteristic, // Disable if loading
                              icon: const Icon(
                                Icons.bluetooth_connected,
                              ), // Icon for reconnect
                              label: const Text(
                                'Reconnect',
                              ), // Label for reconnect button
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors
                                    .blueAccent, // Different color for reconnect
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                      ],
                    ),
              // Display Battery Data
              if (_batteryData != null)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 16.0),
                  elevation: 4.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Battery Data:',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('BMS Mode: ${_batteryData!.bmsModeString}'),
                        Text(
                          'Max Charge Power: ${(_batteryData!.maxChargePowerWatt * 0.1).toStringAsFixed(1)} W',
                        ),
                        Text(
                          'Max Charge Current: ${(_batteryData!.maxChargeCurrentAmp * 0.2).toStringAsFixed(1)} A',
                        ),
                        Text(
                          'Battery SOC: ${(_batteryData!.batterySOC * 0.05).toStringAsFixed(2)} %',
                        ),
                        Text(
                          'Usable Energy: ${(_batteryData!.usableEnergyAmountWh * 5).toStringAsFixed(0)} Wh',
                        ),
                        Text(
                          'Power Discharge: ${(_batteryData!.powerDischargePercentage * 0.2).toStringAsFixed(1)} %',
                        ),
                        Text(
                          'Power Charge: ${(_batteryData!.powerChargePercentage * 0.2).toStringAsFixed(1)} %',
                        ),
                        Text(
                          'Temp Status Charge: ${_batteryData!.temperatureStatusString}',
                        ),
                        Text(
                          'Performance Index Charge Peak Temp: ${(_batteryData!.performanceIndexChargePeakTemperaturePercentage * 0.2).toStringAsFixed(1)} %',
                        ),
                        Text(
                          'Battery Min Temp: ${((_batteryData!.batteryMinTemp * 0.5) - 40).toStringAsFixed(1)} °C',
                        ),
                        Text(
                          'Battery Max Temp: ${((_batteryData!.batteryMaxTemp * 0.5) - 40).toStringAsFixed(1)} °C',
                        ),
                        Text(
                          'Battery Heating Active: ${_batteryData!.batteryHeatingActive ? 'Yes' : 'No'}',
                        ),
                        Text(
                          'Power Battery Heating: ${(_batteryData!.powerBatteryHeatingWatt).toStringAsFixed(0)} W',
                        ),
                        Text(
                          'Power Battery Heating Req: ${(_batteryData!.powerBatteryHeatingReqWatt).toStringAsFixed(0)} W',
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 6.0), // Add some spacing between buttons
            ],
          ),
        ),
      ),
    );
  }
}

