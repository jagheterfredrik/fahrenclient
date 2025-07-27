import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:convert';

import 'package:fahrenclient/battery_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import provider
import 'package:fahrenclient/device_state.dart'; // Import DeviceState
import 'package:fahrenclient/device_selection_page.dart';
import 'package:universal_ble/universal_ble.dart';

class DetailedViewPageV2 extends StatefulWidget {
  final String uuid; // The UUID to display
  final String? deviceName; // New: Optional device name
  final BatteryData? demoBatteryData; // New: Optional demo battery data

  const DetailedViewPageV2({
    super.key,
    required this.uuid,
    this.deviceName,
    this.demoBatteryData, // Add to constructor
  });

  @override
  _DetailedViewPageV2State createState() => _DetailedViewPageV2State();
}

class _DetailedViewPageV2State extends State<DetailedViewPageV2> {
  bool _isConnected = false;
  bool _isLoadingCharacteristic = false;
  bool? _isHeatingEnabled;
  String? _errorMessage;
  bool _isHeatingCharacteristicUpdating = false; // New state for heating characteristic update
  StreamSubscription? _scanSubscription; // Add a subscription for scan stream
  StreamSubscription? _batteryDataSubscription; // Subscription for battery data
  Completer<void>?
  _deviceFoundCompleter; // Completer to signal when device is found
  BatteryData? _batteryData; // To store the parsed battery data

  // Define the service and characteristic UUIDs
  final String _serviceUuid = BleUuidParser.string('ABCD');
  final String _heatingCharacteristicUuid =
      BleUuidParser.string('DEAD'); // Characteristic for heating enabled (0 or 1)
  final String _manufacturerNameCharacteristicUuid =
      'F00D'; // New characteristic for manufacturer name
  final String _batteryDataCharacteristicUuid =
      'BABE'; // Characteristic for battery data notifications

  late TextEditingController
  _nameController; // Controller for the editable name field

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.deviceName,
    ); // Initialize with passed device name

    if (widget.demoBatteryData != null) {
      // If in demo mode, use the provided static data
      setState(() {
        _batteryData = widget.demoBatteryData;
        _isConnected = true; // Simulate connected state for demo
      });
    } else {
      // Otherwise, proceed with BLE connection
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
      await UniversalBle.connect(widget.uuid, connectionTimeout: Duration(seconds: 10));
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

      await UniversalBle.discoverServices(widget.uuid);

      final Uint8List value = await UniversalBle.read(
        widget.uuid,
        _serviceUuid,
        _heatingCharacteristicUuid,
      );

      final Uint8List manufacturerNameValue = await UniversalBle.read(
        widget.uuid,
        _serviceUuid,
        _manufacturerNameCharacteristicUuid,
      );

      if (!mounted) return;
      setState(() {
        _isHeatingEnabled = value.isNotEmpty && value[0] == 0x01;
        try {
          _nameController.text = utf8.decode(
            manufacturerNameValue,
          ); // Update name controller with read value
        } catch (e) {
          print("Name is fucked");
        }
        _isLoadingCharacteristic = false;
      });

      UniversalBle.onValueChange = _handleValueChange;
      // Subscribe to battery data characteristic after successful connection
      _subscribeToBatteryData();
      // Subscribe to heating characteristic after successful connection
      _subscribeToHeatingCharacteristic();
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

      print('Subscribed to battery data characteristic.');
    } catch (e) {
      print('Error subscribing to battery data: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error subscribing to battery data: $e';
      });
    }
  }

  // Function to subscribe to heating characteristic
  Future<void> _subscribeToHeatingCharacteristic() async {
    try {
      await UniversalBle.subscribeNotifications(
        widget.uuid,
        _serviceUuid,
        _heatingCharacteristicUuid,
      );
      print('Subscribed to heating characteristic.');
    } catch (e) {
      print('Error subscribing to heating characteristic: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error subscribing to heating characteristic: $e';
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
    } else if (deviceId == widget.uuid &&
        BleUuidParser.compareStrings(
          characteristicId,
          _heatingCharacteristicUuid,
        )) {
      setState(() {
        _isHeatingEnabled = value.isNotEmpty && value[0] == 0x01;
        _isHeatingCharacteristicUpdating = false; // Reset loading state on notification
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
    setState(() {
      _isHeatingCharacteristicUpdating = true; // Set loading state to true
      _errorMessage = null; // Clear any previous error message
    });
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
      // Do NOT update _isHeatingEnabled here. Wait for notification.
      if (!mounted) return;
      // No setState here, wait for notification
    } catch (e) {
      print('Error writing heating characteristic: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error writing heating status: $e';
        _isHeatingCharacteristicUpdating = false; // Reset loading state on error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom Header - Adjusted for perfect centering
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Stack(
                alignment: Alignment.center, // This centers the text horizontally
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Device Name',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.white70),
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24),
                    textAlign: TextAlign.center,
                    onEditingComplete: () =>
                        _writeManufacturerName(_nameController.text),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: Icon(
                        Icons.electric_car,
                        color: Colors.white70,
                        size: 30,
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DeviceSelectionPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_isLoadingCharacteristic)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Connecting...', textAlign: TextAlign.center),
                ],
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              )
            else if (!_isConnected)
              Column(
                children: [
                  const Text(
                    'Device disconnected or connection failed.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
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
                      backgroundColor: Colors.blueAccent, // Different color for reconnect
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
              )
            else
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Instantaneous power',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 100,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
                                children: [
                                  Text(
                                    _batteryData != null
                                        ? ((_batteryData!.bmsCurrent - 16300) * (_batteryData!.bmsVoltage * 2.5) / -100).toStringAsFixed(0)
                                        : 'N/A',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 48),
                                  ),
                                  Text(
                                    'kW',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 20),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'State of Charge',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: 100,
                              height: 100,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 90,
                                    height: 90,
                                    child: CircularProgressIndicator(
                                      value: _batteryData != null ? (_batteryData!.batterySOC * 0.05) / 100 : 0.0,
                                      strokeWidth: 8,
                                      backgroundColor: Colors.grey[800],
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                    ),
                                  ),
                                  Text(
                                    _batteryData != null
                                        ? '${(_batteryData!.batterySOC * 0.05).toStringAsFixed(0)}%'
                                        : 'N/A',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Voltage and Temperature Section
                  Row(
                    children: [
                      Expanded(
                        child: _buildVoltageCard(
                          context,
                          _batteryData?.cellVoltageMin ?? 0,
                          _batteryData?.cellVoltageMax ?? 0,
                          0.6, // This value is hardcoded in the original, might need adjustment
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTemperatureCard(
                          context,
                          ((_batteryData?.batteryMinTemp ?? 0) * 0.5) - 40,
                          ((_batteryData?.batteryMaxTemp ?? 0) * 0.5) - 40,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // New: Charging Information and Battery Heater Information Section
                  Row(
                    children: [
                      Expanded(
                        child: _buildChargingInfoCard(
                          context,
                          _batteryData?.bmsModeString ?? 'N/A',
                          (_batteryData?.maxChargePowerWatt ?? 0) * .1,
                          (_batteryData?.maxChargeCurrentAmp ?? 0) * 0.2,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildBatteryHeaterCard(
                          context,
                          _batteryData?.batteryHeatingActive == true ? 'Active' : 'Not Active',
                          ((_batteryData?.powerBatteryHeatingWatt ?? 0).toDouble()/1.06).toInt(),
                          ((_batteryData?.powerBatteryHeatingReqWatt ?? 0).toDouble()/1.06).toInt(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20), // Space before the new button

                  // New: Enable Battery Heater Button
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _isHeatingCharacteristicUpdating || _isLoadingCharacteristic
                          ? null
                          : () => _writeHeatingCharacteristic(!(_isHeatingEnabled ?? false)),
                      icon: const Icon(Icons.power_settings_new),
                      label: Text(
                        _isHeatingEnabled == true
                            ? 'Disable Battery Heater'
                            : 'Enable Battery Heater',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isHeatingEnabled == true ? Colors.red : Colors.green, // Use primary color
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build voltage cards
  Widget _buildVoltageCard(
    BuildContext context,
    int minValue,
    int maxValue,
    double progress,
    Color progressColor,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cell voltage',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.battery_full, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Δ ${maxValue - minValue} mV',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 28),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Display min value left-aligned and max value right-aligned
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Min\n${minValue + 1000} mV',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                Text(
                  'Max\n${maxValue + 1000} mV',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build temperature cards
  Widget _buildTemperatureCard(
    BuildContext context,
    double minValue,
    double maxValue,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pack Temperature',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.thermostat, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  '${minValue.toStringAsFixed(1)}°C',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 28),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Δ\n${(maxValue - minValue).toStringAsFixed(1)}°C',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                Text(
                  'Max\n${maxValue.toStringAsFixed(1)}°C',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // New: Helper widget to build Charging Information card
  Widget _buildChargingInfoCard(
    BuildContext context,
    String chargeStatus,
    double estimatedPower,
    double estimatedCurrent,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Charging',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.battery_charging_full, color: Colors.green),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chargeStatus,
                      style: Theme.of(context).textTheme.titleMedium,
                    )
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estimated\n${estimatedPower.toStringAsFixed(1)} kW',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                Text(
                  '\n${estimatedCurrent.toStringAsFixed(1)} A',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // New: Helper widget to build Battery Heater Information card
  Widget _buildBatteryHeaterCard(
    BuildContext context,
    String status,
    int duty,
    int requested,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Battery Heater',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.fireplace, color: Colors.green),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      style: Theme.of(context).textTheme.titleMedium,
                    )
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Duty\n${duty}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                Text(
                  'Requested\n${requested}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
