import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import provider
import 'package:fahrenclient/device_state.dart'; // Import DeviceState
import 'package:fahrenclient/device_selection_page.dart'; // Import DeviceSelectionPage
import 'package:fahrenclient/detailed_view_page.dart'; // Import DetailedViewPage
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => DeviceState()..loadSelectedDevice(),
      child: const PermissionHandlerWrapper(),
    ),
  );
}

class PermissionHandlerWrapper extends StatefulWidget {
  const PermissionHandlerWrapper({super.key});

  @override
  State<PermissionHandlerWrapper> createState() => _PermissionHandlerWrapperState();
}

class _PermissionHandlerWrapperState extends State<PermissionHandlerWrapper> {
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      if (statuses[Permission.bluetoothScan] == PermissionStatus.granted &&
          statuses[Permission.bluetoothConnect] == PermissionStatus.granted) {
        setState(() {
          _permissionsGranted = true;
        });
      } else {
        // Handle the case where permissions are not granted.
        // You might want to show a dialog or navigate to a page explaining why permissions are needed.
        // For now, we'll just print a message.
        print('Bluetooth permissions not granted.');
      }
    } else {
      // For non-Android platforms, assume permissions are not needed or handled differently.
      setState(() {
        _permissionsGranted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionsGranted) {
      return const MyApp();
    } else {
      return MaterialApp(
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
  }
}

// This is the main application widget.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fahrenheat App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Consumer<DeviceState>(
        builder: (context, deviceState, child) {
          if (deviceState.selectedDeviceId == null && !deviceState.isDeviceSelected) {
            // If no device is selected and not loading, show DeviceSelectionPage
            return DeviceSelectionPage();
          } else if (deviceState.selectedDeviceId != null) {
            // If a device is selected, show DetailedViewPage
            return DetailedViewPage(
              uuid: deviceState.selectedDeviceId!,
              deviceName: deviceState.selectedDeviceName,
            );
          } else {
            // Show a loading indicator while the device state is being loaded
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
        },
      ),
    );
  }
}

