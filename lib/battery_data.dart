import 'dart:typed_data'; // For Uint8List

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
