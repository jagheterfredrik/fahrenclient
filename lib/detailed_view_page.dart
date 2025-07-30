import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:convert';

import 'package:fahrenclient/battery_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fahrenclient/device_state.dart';
import 'package:fahrenclient/device_selection_page.dart';
import 'package:universal_ble/universal_ble.dart';

class DetailedViewPage extends StatefulWidget {
  final String uuid;
  final String? deviceName;
  final BatteryData? demoBatteryData;

  const DetailedViewPage({
    super.key,
    required this.uuid,
    this.deviceName,
    this.demoBatteryData,
  });

  @override
  _DetailedViewPageState createState() => _DetailedViewPageState();
}

class _DetailedViewPageState extends State<DetailedViewPage> {
  bool _isConnected = false;
  bool _isLoadingCharacteristic = false;
  bool? _isHeatingEnabled;
  bool _isHeatingCharacteristicUpdating = false;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _batteryDataSubscription;
  Completer<void>? _deviceFoundCompleter;
  BatteryData? _batteryData;
  bool _showUsableEnergy = false;
  ScaffoldMessengerState? _scaffoldMessengerState;

  final String _serviceUuid = BleUuidParser.string('ABCD');
  final String _heatingCharacteristicUuid =
      BleUuidParser.string('DEAD');
  final String _manufacturerNameCharacteristicUuid =
      'F00D';
  final String _batteryDataCharacteristicUuid =
      'BABE';

  late TextEditingController
  _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.deviceName,
    );

    if (widget.demoBatteryData != null) {
      // Use static data in demo mode
      setState(() {
        _batteryData = widget.demoBatteryData;
        _isConnected = true;
      });
    } else {
      // Proceed with BLE connection
      _connectAndReadCharacteristic();
    
      // Listen to the connection stream to update the UI
      UniversalBle.connectionStream(widget.uuid).listen((bool isConnected) {
        if (!mounted) return;
        setState(() {
          _isConnected = isConnected;
          if (!isConnected) {
            _batteryData = null;
          }
        });
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessengerState = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldMessengerState?.removeCurrentSnackBar();
    });
    _nameController.dispose();
    _disconnect();
    _batteryDataSubscription?.cancel();
    UniversalBle.onValueChange = null;
    _stopScan();
    super.dispose();
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: GestureDetector(
          onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          child: Text(message),
        ),
        duration: const Duration(seconds: 10),
      ),
    );
  }

  void _stopScan() async {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    if (_deviceFoundCompleter != null && !_deviceFoundCompleter!.isCompleted) {
      _deviceFoundCompleter!.complete();
    }
    await UniversalBle.stopScan();
  }

  // Connects to the device, discovers services, and reads characteristics.
  Future<void> _connectAndReadCharacteristic() async {
    if (!mounted) return;

    setState(() {
      _isLoadingCharacteristic = true;
    });

    try {
      // On iOS, a scan is required to connect to a known device.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        BleDevice? foundDevice;
        _stopScan();
        _deviceFoundCompleter = Completer<void>();

        _scanSubscription = UniversalBle.scanStream.listen((scanResult) {
          if (scanResult.deviceId == widget.uuid) {
            foundDevice = scanResult;
            _stopScan();
            if (!_deviceFoundCompleter!.isCompleted) {
              _deviceFoundCompleter!.complete();
            }
          }
        });

        await UniversalBle.startScan(
          scanFilter: ScanFilter(withServices: [_serviceUuid]),
        );

        // Wait for the device to be found, with a timeout.
        await _deviceFoundCompleter!.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            return;
          },
        );

        _stopScan();

        if (foundDevice == null) {
          throw Exception(
            'Device ${widget.deviceName ?? widget.uuid} not found during scan. Please ensure it is advertising.',
          );
        }
      }

      // Connect to the device.
      await UniversalBle.connect(widget.uuid,
          connectionTimeout: const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _isConnected = true;
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar('Could not connect to device.');
      setState(() {
        _isLoadingCharacteristic = false;
        _isConnected = false;
      });
      return;
    }

    try {
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
          );
        } catch (e) {
          // Ignore errors decoding the manufacturer name.
        }
        _isLoadingCharacteristic = false;
      });

      UniversalBle.onValueChange = _handleValueChange;
      
      await _subscribeToBatteryData();
      await _subscribeToHeatingCharacteristic();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar(
          'Could not read or subscribe to characteristic. ($e)');
      await _disconnect();
      setState(() {
        _isLoadingCharacteristic = false;
      });
    }
  }

  Future<void> _subscribeToBatteryData() async {
    await UniversalBle.subscribeNotifications(
      widget.uuid,
      _serviceUuid,
      _batteryDataCharacteristicUuid,
    );

  }

  Future<void> _subscribeToHeatingCharacteristic() async {
    await UniversalBle.subscribeNotifications(
      widget.uuid,
      _serviceUuid,
      _heatingCharacteristicUuid,
    );
  }

  // Handles characteristic value changes from the BLE device.
  void _handleValueChange(
    String deviceId,
    String characteristicId,
    Uint8List value,
  ) {
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
        _isHeatingCharacteristicUpdating = false;
      });
    }
  }

  // Disconnects from the BLE device.
  Future<void> _disconnect() async {
    try {
      await UniversalBle.disconnect(widget.uuid);
      if (!mounted) return;
      setState(() {
        _isConnected = false;
        _batteryData = null;
      });
    } catch (e) {
    }
  }

  // Writes the new manufacturer name to the appropriate characteristic.
  Future<void> _writeManufacturerName(String newName) async {
    if (!_isConnected) {
      _showErrorSnackbar('Error: Not connected to device.');
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
      // Persist the new name.
      Provider.of<DeviceState>(
        context,
        listen: false,
      ).setSelectedDevice(widget.uuid, newName);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar('Error writing name: $e');
    }
  }

  // Writes the heating characteristic value.
  Future<void> _writeHeatingCharacteristic(bool enableHeating) async {
    if (!_isConnected) {
      _showErrorSnackbar('Error: Not connected to device.');
      return;
    }
    setState(() {
      _isHeatingCharacteristicUpdating = true;
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
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar('Error writing heating status: $e');
      setState(() {
        _isHeatingCharacteristicUpdating = false;
      });
    }
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _batteryData != null
                                ? (() {
                                    double power = (_batteryData!.bmsCurrent - 16300) * (_batteryData!.bmsVoltage * 2.5) / -100;
                                    if (power.abs() < 1000) {
                                      return '${power.toStringAsFixed(0)}';
                                    } else {
                                      return '${(power / 1000).toStringAsFixed(2)}';
                                    }
                                  })()
                                : 'N/A',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 36),
                          ),
                          Text(
                            ((_batteryData!.bmsCurrent - 16300) * (_batteryData!.bmsVoltage * 2.5) / -100).abs() < 1000 ? 'W' : 'kW',
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
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showUsableEnergy = !_showUsableEnergy;
                        });
                      },
                      child: SizedBox(
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
                                  ? (_showUsableEnergy
                                      ? '${(_batteryData!.usableEnergyAmountWh * 5).toStringAsFixed(0)} Wh'
                                      : '${(_batteryData!.batterySOC * 0.05).toStringAsFixed(0)}%')
                                  : 'N/A',
                              style: _showUsableEnergy ? Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 12) : Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Charging and battery heater information
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
              const SizedBox(width: 8),
              Expanded(
                child: _buildBatteryHeaterCard(
                  context,
                  _batteryData?.batteryHeatingActive == true ? 'Active' : 'Not Active',
                  ((_batteryData!.powerBatteryHeatingWatt ?? 0).toDouble() / 1.06)
                      .toInt(),
                  ((_batteryData!.powerBatteryHeatingReqWatt ?? 0).toDouble() / 1.06)
                      .toInt(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

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
              const SizedBox(width: 8),
              Expanded(
                child: _buildTemperatureCard(
                  context,
                  _batteryData?.temperatureStatusString ?? "Unknown",
                  ((_batteryData?.batteryMinTemp ?? 0) * 0.5) - 40,
                  ((_batteryData?.batteryMaxTemp ?? 0) * 0.5) - 40,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // "Enable Battery Heater" button
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
                backgroundColor: _isHeatingEnabled == true ? Colors.red : Colors.green,
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
    );
  }

  Widget _buildStatusScreens() {
    if (_isLoadingCharacteristic) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Connecting...', textAlign: TextAlign.center),
          ],
        ),
      );
    } else if (!_isConnected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
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
                  : _connectAndReadCharacteristic,
              icon: const Icon(
                Icons.bluetooth_connected,
              ),
              label: const Text(
                'Reconnect',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
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
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Stack(
          alignment: Alignment.center,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Device Name',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white70),
              ),
              style:
                  Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24),
              textAlign: TextAlign.center,
              onEditingComplete: () =>
                  _writeManufacturerName(_nameController.text),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(
                  Icons.electric_car,
                  color: Colors.white70,
                  size: 30,
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DeviceSelectionPage(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          if (_isConnected)
            _buildMainContent(),
          if (_isLoadingCharacteristic || !_isConnected)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: _buildStatusScreens(),
            ),
        ],
      ),
    );
  }

  // Builds the voltage information card.
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
                const SizedBox(width: 4),
                Text(
                  'Δ ${maxValue - minValue} mV',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Display min and max voltage values.
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

  // Builds the temperature information card.
  Widget _buildTemperatureCard(
    BuildContext context,
    String status,
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
                const SizedBox(width: 4),
                Text(
                  status,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Min\n${minValue.toStringAsFixed(1)}°C',
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

  // Builds the charging information card.
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
                const SizedBox(width: 4),
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

  // Builds the battery heater information card.
  Widget _buildBatteryHeaterCard(
    BuildContext context,
    String status,
    int duty,
    int requested,
  ) {
    return Card(
      // elevation: 0,
      surfaceTintColor: Colors.transparent,
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
                const SizedBox(width: 7),
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
                  'Duty\n$duty%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                Text(
                  'Requested\n$requested%',
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
