import 'dart:typed_data'; // For Uint8List

class BatteryData {
  final int bmsMode; // uint8_t
  final int bmsCurrent; // uint16_t, X - 16300
  final int bmsVoltage; // uint16_t, X * 2.5
  final int maxChargePowerWatt; // uint16_t, X * 0.1
  final int maxChargeCurrentAmp; // uint16_t, X * 0.2
  final int batterySOC; // uint16_t, X * 0.05
  final int usableEnergyAmountWh; // uint16_t, X * 5
  final int temperatureStatusCharge; // uint8_t
  final int performanceIndexChargePeakTemperaturePercentage; // uint16_t, X * 0.2
  final int batteryMinTemp; // uint8_t, X * 0.5 - 40
  final int batteryMaxTemp; // uint8_t, X * 0.5 - 40
  final int cellVoltageMax; // uint16_t, X + 1000
  final int cellVoltageMin; // uint16_t, X + 1000
  final bool batteryHeatingActive; // uint8_t (bool)
  final int powerBatteryHeatingWatt; // uint8_t
  final int powerBatteryHeatingReqWatt; // uint8_t

  BatteryData({
    required this.bmsMode,
    required this.bmsCurrent,
    required this.bmsVoltage,
    required this.maxChargePowerWatt,
    required this.maxChargeCurrentAmp,
    required this.batterySOC,
    required this.usableEnergyAmountWh,
    required this.temperatureStatusCharge,
    required this.performanceIndexChargePeakTemperaturePercentage,
    required this.batteryMinTemp,
    required this.batteryMaxTemp,
    required this.cellVoltageMax,
    required this.cellVoltageMin,
    required this.batteryHeatingActive,
    required this.powerBatteryHeatingWatt,
    required this.powerBatteryHeatingReqWatt,
  });

  factory BatteryData.fromBytes(Uint8List bytes) {
    final ByteData byteData = ByteData.sublistView(bytes);
    int offset = 0;
    final int bmsMode = byteData.getUint8(offset);
    offset += 1;
    final int bmsCurrent = byteData.getUint16(offset, Endian.little);
    offset += 2;
    final int bmsVoltage = byteData.getUint16(offset, Endian.little);
    offset += 2;
    final int maxChargePowerWatt = byteData.getUint16(offset, Endian.little);
    offset += 2;
    final int maxChargeCurrentAmp = byteData.getUint16(offset, Endian.little);
    offset += 2;
    final int batterySOC = byteData.getUint16(offset, Endian.little);
    offset += 2;
    final int usableEnergyAmountWh = byteData.getUint16(offset, Endian.little);
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
    final int cellVoltageMax = byteData.getUint16(offset, Endian.little);
    offset += 2;
    final int cellVoltageMin = byteData.getUint16(offset, Endian.little);
    offset += 2;
    final bool batteryHeatingActive = byteData.getUint8(offset) == 1;
    offset += 1;
    final int powerBatteryHeatingWatt = byteData.getUint8(offset);
    offset += 1;
    final int powerBatteryHeatingReqWatt = byteData.getUint8(offset);
    offset += 1;

    return BatteryData(
      bmsMode: bmsMode,
      bmsCurrent: bmsCurrent,
      bmsVoltage: bmsVoltage,
      maxChargePowerWatt: maxChargePowerWatt,
      maxChargeCurrentAmp: maxChargeCurrentAmp,
      batterySOC: batterySOC,
      usableEnergyAmountWh: usableEnergyAmountWh,
      temperatureStatusCharge: temperatureStatusCharge,
      performanceIndexChargePeakTemperaturePercentage:
          performanceIndexChargePeakTemperaturePercentage,
      batteryMinTemp: batteryMinTemp,
      batteryMaxTemp: batteryMaxTemp,
      cellVoltageMax: cellVoltageMax,
      cellVoltageMin: cellVoltageMin,
      batteryHeatingActive: batteryHeatingActive,
      powerBatteryHeatingWatt: powerBatteryHeatingWatt,
      powerBatteryHeatingReqWatt: powerBatteryHeatingReqWatt,
    );
  }

  // Helper to get temperature status string
  String get temperatureStatusDetailedString {
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

  String get temperatureStatusString {
    switch (temperatureStatusCharge) {
      case 1:
        return 'Suboptimal';
      case 2:
        return 'Optimal';
      case 3:
        return 'Hot';
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
        return 'Ready';
      case 2:
        return 'Balancing';
      case 3:
        return 'Charging';
      case 4:
        return 'AC Charging';
      case 5:
        return 'Error';
      case 6:
        return 'DC Charging';
      case 7:
        return 'Initializing';
      default:
        return 'Unknown';
    }
  }

  String get bmsModeDetailedString {
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
