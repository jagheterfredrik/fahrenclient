import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fahrenclient/device_state.dart';
import 'package:fahrenclient/device_selection_page.dart';
import 'package:fahrenclient/detailed_view_page.dart';
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
        // Handle the case where permissions are not granted, e.g., by showing a dialog.
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fahrenheat App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark, // Dark theme
        // primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF1C1C1E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          labelLarge: TextStyle(color: Colors.white),
        ),
        cardTheme:  CardTheme.of(context).copyWith(color: const Color(0xFF2C2C2E)),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green, // Button background color
            foregroundColor: Colors.white, // Button text color
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), // Rounded corners for buttons
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.green), // Border color
            foregroundColor: Colors.green, // Text color
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), // Rounded corners
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: Consumer<DeviceState>(
        builder: (context, deviceState, child) {
          if (deviceState.selectedDeviceId == null && !deviceState.isDeviceSelected) {
            // If no device is selected and not loading, show DeviceSelectionPage
            return DeviceSelectionPage();
          } else if (deviceState.selectedDeviceId != null) {
            return DetailedViewPage(
              uuid: deviceState.selectedDeviceId!,
              deviceName: deviceState.selectedDeviceName,
              isDemoMode: false,
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

