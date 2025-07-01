import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import provider
import 'package:fahrenclient/device_state.dart'; // Import DeviceState
import 'package:fahrenclient/device_selection_page.dart'; // Import DeviceSelectionPage
import 'package:fahrenclient/detailed_view_page.dart'; // Import DetailedViewPage

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => DeviceState()..loadSelectedDevice(),
      child: const MyApp(),
    ),
  );
}

// This is the main application widget.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fahrenheat App',
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

