import 'dart:async';

import 'package:get/get.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart' show BleStatus;
import 'package:bletest/models/device.dart';
import 'package:bletest/services/ble_service.dart';
import 'package:bletest/floatingbar.dart';

enum BluetoothIconState { on, off, scanning }

class HomeController extends GetxController {
  final BLEService _ble = Get.find<BLEService>();

  StreamSubscription<bool> _isScanningSub;

  final isScanning = false.obs;
  final btIconState = BluetoothIconState.off.obs;
  final _btState = BleStatus.poweredOff.obs;
  final isEnabled = false.obs;
  final scannedDevices = <Device>[].obs;
  final connectedDevices = <Device>[].obs;

  @override
  void onInit() {
    super.onInit();
    _btState.bindStream(_ble.getState);
    ever(_btState, _updateState);
    scannedDevices(_ble.getScannedDevices);
    connectedDevices(_ble.getConnectedDevices);
    _isScanningSub =
        _ble.isScanning.listen((_isScanning) => _updateScanning(_isScanning));
  }

  void onScan() {
    if (!isScanning.value)
      _ble
          .startScan()
          .catchError((error) => FloatingBar.alertBar(message: error));
    else
      _ble.stopScan();
  }

  void onConnect(Device device) => _ble.connect(device);

  void onDisconnect(Device device) => _ble.disconnect(device);

  @override
  void onClose() {
    super.onClose();
    _btState.close();
    isScanning.close();
    _isScanningSub.cancel();
  }

  void _updateScanning(bool _isScanning) {
    isScanning.value = _isScanning;
    if (_isScanning) {
      btIconState.value = BluetoothIconState.scanning;
    } else {
      if (btIconState.value != BluetoothIconState.off)
        btIconState.value = BluetoothIconState.on;
      if (scannedDevices.isEmpty)
        FloatingBar.infoBar(message: 'No devices found');
    }
  }

  void _updateState(BleStatus state) {
    switch (state) {
      case BleStatus.ready:
        if (isScanning.value &&
            btIconState.value == BluetoothIconState.scanning) return;
        btIconState.value = BluetoothIconState.on;
        break;
      default: // Off, unauthorized, unavailable, unknown
        connectedDevices.clear();
        scannedDevices.clear();
        btIconState.value = BluetoothIconState.off;
    }
  }
}
