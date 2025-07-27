import 'package:flutter/material.dart';

class DetailedViewPageV2 extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Battery Monitor',
      theme: ThemeData(
        brightness: Brightness.dark, // Dark theme
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF1C1C1E), // Dark background
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
        cardColor: const Color(0xFF2C2C2E), // Card background
        // Define button themes for a modern look
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
      home: const BatteryMonitorScreen(),
    );
  }
}

class BatteryMonitorScreen extends StatelessWidget {
  const BatteryMonitorScreen({super.key});

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
                  Text(
                    'ID.4',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.electric_car, color: Colors.white, size: 30),
                      onPressed: () {
                        // Handle car icon tap
                        print('Car icon tapped!');
                        // You can add navigation or other actions here
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

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
                              '1258',
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
                                value: 0.74,
                                strokeWidth: 8,
                                backgroundColor: Colors.grey[800],
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                              ),
                            ),
                            Text(
                              '74%',
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
                    3678, // Min value
                    3686, // Max value
                    0.6,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTemperatureCard(
                    context,
                    23.5,
                    24.5,
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
                    'Not Charging',
                    125.2,
                    450,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildBatteryHeaterCard(
                    context,
                    'Not Active',
                    0,
                    0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20), // Space before the new button

            // New: Enable Battery Heater Button
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Handle enable battery heater action
                  print('Enable Battery Heater button tapped!');
                  // You can add logic here to enable the heater
                },
                icon: const Icon(Icons.power_settings_new),
                label: const Text('Enable Battery Heater'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // Use primary color
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
                  'Min\n$minValue mV',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                Text(
                  'Max\n$maxValue mV',
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
                  '${minValue}°C',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 28),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Δ\n${maxValue - minValue}°C',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                Text(
                  'Max\n${maxValue}°C',
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
                  'Estimated\n$estimatedPower kW',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                Text(
                  '\n$estimatedCurrent A',
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
