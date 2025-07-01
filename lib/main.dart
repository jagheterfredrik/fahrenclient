import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart'; // Import the universal_ble library
import 'dart:async'; // For Timer and StreamSubscription
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'dart:convert'; // For utf8.decode
import 'dart:typed_data'; // For Uint8List
import 'package:flutter/foundation.dart'; // Add this import

// Keys for storing the selected device ID and name in SharedPreferences
const String _kSelectedDeviceIdKey = 'selected_device_id';
const String _kSelectedDeviceNameKey =
    'selected_device_name'; // New key for device name

// This is the main application widget.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _initialDeviceId;
  String? _initialDeviceName; // To store the initial device name
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSelectedDeviceId();
  }

  // Loads the previously selected device ID and name from shared preferences
  Future<void> _loadSelectedDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _initialDeviceId = prefs.getString(_kSelectedDeviceIdKey);
      _initialDeviceName = prefs.getString(
        _kSelectedDeviceNameKey,
      ); // Load the name
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child:
                CircularProgressIndicator(), // Show a loading indicator while checking preferences
          ),
        ),
      );
    }

    if (kIsWeb) {
      // On web, always go to device selection, but pass the remembered name
      return MaterialApp(
        title: 'Fahrenheat App',
        theme: ThemeData(
          primarySwatch: Colors.deepPurple,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: DeviceSelectionPage(
          rememberedDeviceName: _initialDeviceName,
          rememberedDeviceId: _initialDeviceId,
        ),
      );
    }

    // On mobile, auto-reconnect if possible
    return MaterialApp(
      title: 'Fahrenheat App',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: _initialDeviceId == null
          ? DeviceSelectionPage()
          : DetailedViewPage(
              uuid: _initialDeviceId!,
              deviceName: _initialDeviceName,
            ),
    );
  }
}

// This is the new onboarding page for device selection.
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
            _scannedDevices[existingIndex] = scanResult;
          }
        });
      });

      // On web, filter by both service and name if remembered
      ScanFilter filter;
      if (kIsWeb &&
          widget.rememberedDeviceName != null &&
          widget.rememberedDeviceName!.isNotEmpty) {
        filter = ScanFilter(withServices: ['ABCD']);
      } else {
        filter = ScanFilter(withServices: ['ABCD']);
      }

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedDeviceIdKey, device.deviceId);
    // Save the manufacturer data as the device name
    await prefs.setString(
      _kSelectedDeviceNameKey,
      _getDeviceDisplayName(device),
    );

    // Navigate to the DetailedViewPage, replacing the current route
    if (mounted) {
      // Ensure the widget is still mounted before navigation
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DetailedViewPage(
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
        ],
      ),
    );
  }
}

// A page to display the details of a selected UUID.
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
  void _handleValueChange(String deviceId, String characteristicId, Uint8List value) {
    // print("Got data! $deviceId $characteristicId");
    if (deviceId == widget.uuid && BleUuidParser.compareStrings(characteristicId, _batteryDataCharacteristicUuid)) {
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

  // Clears the selected device ID from SharedPreferences and navigates back
  Future<void> _clearSelectedDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSelectedDeviceIdKey);
    await prefs.remove(_kSelectedDeviceNameKey); // Remove the name as well
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
      // Store the new name to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSelectedDeviceNameKey, newName);
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
      final Uint8List valueToWrite =
          Uint8List.fromList([enableHeating ? 0x01 : 0x00]);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            _clearSelectedDeviceId().then((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => DeviceSelectionPage(),
                ),
              );
            });
          },
        ),
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
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: () => _writeManufacturerName(_nameController.text),
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
              // Moved connection status to the body
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    color: _isConnected ? Colors.green : Colors.redAccent,
                    size: 24.0,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isConnected ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isConnected ? Colors.green : Colors.redAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20), // Add some spacing

              // Display connection and characteristic status
              _isLoadingCharacteristic
                  ? const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Connecting...',
                          textAlign: TextAlign.center,
                        ),
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
                        if (_isHeatingEnabled != null && _isConnected) // Add _isConnected condition
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Heating Enabled:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                              Switch(
                                value: _isHeatingEnabled!,
                                onChanged: (bool newValue) {
                                  _writeHeatingCharacteristic(newValue);
                                },
                                activeColor: _batteryData?.batteryHeatingActive == true ? Colors.green : Colors.grey,
                                inactiveThumbColor: Colors.red,
                                inactiveTrackColor: _batteryData?.batteryHeatingActive == true ? Colors.green.withOpacity(0.5) : Colors.redAccent.withOpacity(0.5),
                              ),
                            ],
                          )
                        else if (!_isConnected) // Display message if disconnected
                          const Text(
                            'Device disconnected. Heating status unavailable.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center,
                          )
                        else // Original else for when _isHeatingEnabled is null but connected
                          const Text(
                            'Heating status not available.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
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
                        Text('Max Charge Power: ${(_batteryData!.maxChargePowerWatt * 0.1).toStringAsFixed(1)} W'),
                        Text('Max Charge Current: ${(_batteryData!.maxChargeCurrentAmp * 0.2).toStringAsFixed(1)} A'),
                        Text('Battery SOC: ${(_batteryData!.batterySOC * 0.05).toStringAsFixed(2)} %'),
                        Text('Usable Energy: ${(_batteryData!.usableEnergyAmountWh * 5).toStringAsFixed(0)} Wh'),
                        Text('Power Discharge: ${(_batteryData!.powerDischargePercentage * 0.2).toStringAsFixed(1)} %'),
                        Text('Power Charge: ${(_batteryData!.powerChargePercentage * 0.2).toStringAsFixed(1)} %'),
                        Text('Temp Status Charge: ${_batteryData!.temperatureStatusString}'),
                        Text('Performance Index Charge Peak Temp: ${(_batteryData!.performanceIndexChargePeakTemperaturePercentage * 0.2).toStringAsFixed(1)} %'),
                        Text('Battery Min Temp: ${((_batteryData!.batteryMinTemp * 0.5) - 40).toStringAsFixed(1)} °C'),
                        Text('Battery Max Temp: ${((_batteryData!.batteryMaxTemp * 0.5) - 40).toStringAsFixed(1)} °C'),
                        Text('Battery Heating Active: ${_batteryData!.batteryHeatingActive ? 'Yes' : 'No'}'),
                        Text('Power Battery Heating: ${(_batteryData!.powerBatteryHeatingWatt).toStringAsFixed(0)} W'),
                        Text('Power Battery Heating Req: ${(_batteryData!.powerBatteryHeatingReqWatt).toStringAsFixed(0)} W'),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12.0),
              ElevatedButton.icon(
                onPressed: _isLoadingCharacteristic
                    ? null
                    : _connectAndReadCharacteristic, // Disable if loading
                icon: const Icon(
                  Icons.bluetooth_connected,
                ), // Icon for reconnect
                label: const Text('Reconnect'), // Label for reconnect button
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.blueAccent, // Different color for reconnect
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
              const SizedBox(height: 6.0), // Add some spacing between buttons
            ],
          ),
        ),
      ),
    );
  }
}

// Define the BatteryData class based on the C struct
class BatteryData {
  final int bmsMode; // uint8_t
  final int maxChargePowerWatt; // uint16_t, X * 0.1
  final int maxChargeCurrentAmp; // uint16_t, X * 0.2
  final int batterySOC; // uint16_t, X * 0.05
  final int usableEnergyAmountWh; // uint16_t, X * 5
  final int powerDischargePercentage; // uint16_t, X * 0.2
  final int powerChargePercentage; // uint16_t, X * 0.2
  final int temperatureStatusCharge; // uint8_t
  final int performanceIndexChargePeakTemperaturePercentage; // uint16_t, X * 0.2
  final int batteryMinTemp; // uint8_t, X * 0.5 - 40
  final int batteryMaxTemp; // uint8_t, X * 0.5 - 40
  final bool batteryHeatingActive; // uint8_t (bool)
  final int powerBatteryHeatingWatt; // uint8_t
  final int powerBatteryHeatingReqWatt; // uint8_t

  BatteryData({
    required this.bmsMode,
    required this.maxChargePowerWatt,
    required this.maxChargeCurrentAmp,
    required this.batterySOC,
    required this.usableEnergyAmountWh,
    required this.powerDischargePercentage,
    required this.powerChargePercentage,
    required this.temperatureStatusCharge,
    required this.performanceIndexChargePeakTemperaturePercentage,
    required this.batteryMinTemp,
    required this.batteryMaxTemp,
    required this.batteryHeatingActive,
    required this.powerBatteryHeatingWatt,
    required this.powerBatteryHeatingReqWatt,
  });

  factory BatteryData.fromBytes(Uint8List bytes) {
    final ByteData byteData = ByteData.sublistView(bytes);
    int offset = 0;
    final int bmsMode = byteData.getUint8(offset);
    offset += 1;
    final int maxChargePowerWatt = byteData.getUint16(offset, Endian.little);
    offset += 2;
    final int maxChargeCurrentAmp = byteData.getUint16(offset, Endian.little);
    offset += 2;
    final int batterySOC = byteData.getUint16(offset, Endian.little);
    offset += 2;
    final int usableEnergyAmountWh = byteData.getUint16(offset, Endian.little);
    offset += 2;
    final int powerDischargePercentage = byteData.getUint16(offset, Endian.little);
    offset += 2;
    final int powerChargePercentage = byteData.getUint16(offset, Endian.little);
    offset += 2;
    final int temperatureStatusCharge = byteData.getUint8(offset);
    offset += 1;
    final int performanceIndexChargePeakTemperaturePercentage =
        byteData.getUint16(offset, Endian.little);
    offset += 2;
    final int batteryMinTemp = byteData.getUint8(offset);
    offset += 1;
    final int batteryMaxTemp = byteData.getUint8(offset);
    offset += 1;
    final bool batteryHeatingActive = byteData.getUint8(offset) == 1;
    offset += 1;
    final int powerBatteryHeatingWatt = byteData.getUint8(offset);
    offset += 1;
    final int powerBatteryHeatingReqWatt = byteData.getUint8(offset);
    offset += 1;

    return BatteryData(
      bmsMode: bmsMode,
      maxChargePowerWatt: maxChargePowerWatt,
      maxChargeCurrentAmp: maxChargeCurrentAmp,
      batterySOC: batterySOC,
      usableEnergyAmountWh: usableEnergyAmountWh,
      powerDischargePercentage: powerDischargePercentage,
      powerChargePercentage: powerChargePercentage,
      temperatureStatusCharge: temperatureStatusCharge,
      performanceIndexChargePeakTemperaturePercentage:
          performanceIndexChargePeakTemperaturePercentage,
      batteryMinTemp: batteryMinTemp,
      batteryMaxTemp: batteryMaxTemp,
      batteryHeatingActive: batteryHeatingActive,
      powerBatteryHeatingWatt: powerBatteryHeatingWatt,
      powerBatteryHeatingReqWatt: powerBatteryHeatingReqWatt,
    );
  }

  // Helper to get temperature status string
  String get temperatureStatusString {
    switch (temperatureStatusCharge) {
      case 0:
        return 'Init';
      case 1:
        return 'Temp Under Optimal';
      case 2:
        return 'Temp Optimal';
      case 3:
        return 'Temp Over Optimal';
      case 7:
        return 'Fault';
      default:
        return 'Unknown';
    }
  }

  // Helper to get BMS mode string
  String get bmsModeString {
    switch (bmsMode) {
      case 0:
        return 'Invalid';
      case 1:
        return 'HV_ACTIVE';
      case 2:
        return 'BALANCING';
      case 3:
        return 'EXTERN CHARGING';
      case 4:
        return 'AC_CHARGING';
      case 5:
        return 'Error';
      case 6:
        return 'DC_CHARGING';
      case 7:
        return 'Init';
      default:
        return 'Unknown';
    }
  }
}

// The main function, the entry point of the Flutter application.
void main() {
  runApp(MyApp());
}
