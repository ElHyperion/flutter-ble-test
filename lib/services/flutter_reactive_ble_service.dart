import 'dart:async';

import 'package:get/get.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart'
    hide DeviceConnectionState;
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart' as ble
    show DeviceConnectionState;
import 'package:bletest/models/device.dart';
import 'package:bletest/services/ble_service.dart';

class FlutterReactiveBLE extends BLEService {
  FlutterReactiveBle _ble;

  var _connectionStreams =
      Map<String, StreamSubscription<ConnectionStateUpdate>>();

  final RxBool _isConnected = false.obs;
  final RxBool _isScanning = false.obs;
  final _scannedDevices = <Device>[].obs;
  final _connectedDevices = <Device>[].obs;

  int _connectedDevicesCount = 0;
  StreamSubscription _scanSub;
  Device _deviceConnectingTo;

  @override
  Future<void> init() async {
    _ble = FlutterReactiveBle();
    _ble.logLevel = LogLevel.none;
    _ble.connectedDeviceStream.listen(_handleConnectionStateUpdates);
  }

  @override
  Stream<BleStatus> get getState => _ble.statusStream;

  @override
  Stream<bool> get isScanning =>
      _isScanning.stream.asBroadcastStream(onListen: (_) {
        if (_isScanning.value) _isScanning.refresh();
      });

  @override
  Stream<bool> get isConnected => _isConnected.stream;

  @override
  RxList<Device> get getScannedDevices => _scannedDevices;

  @override
  RxList<Device> get getConnectedDevices => _connectedDevices;

  @override
  Future<void> startScan() async {
    if (_ble.status != BleStatus.ready) {
      return Future.error('Bluetooth is not enabled');
    } else {
      _scannedDevices.clear();
      _isScanning.value = true;
      _scanSub?.cancel();
      _scanSub = _ble.scanForDevices(
          withServices: [],
          scanMode:
              ScanMode.lowLatency).listen((result) => _addScanResult(result));
      try {
        // TODO: Add a delay for scanning to prevent rapid consecutive scans.
        await _scanSub.asFuture().catchError((e) {
          _isScanning.value = false;
          print('Error during scanning: =====================================');
          print(e.toString());
          return Future.error(
              'Error scanning for devices! Try again in 20 seconds...');
        });
      } catch (e) {
        return Future.error(e);
      }
    }
  }

  @override
  Future<void> stopScan() async {
    _isScanning.value = false;
    _scanSub?.cancel();
  }

  @override
  void connect(Device device) {
    String deviceId = device.id;
    _deviceConnectingTo = device;

    if (!_connectionStreams.containsKey(deviceId)) {
      print('SERVICE: Adding connection stream for $deviceId');
      _connectionStreams[device.id] = _ble
          .connectToDevice(
            id: deviceId,
            connectionTimeout: Duration(seconds: 10),
          )
          .listen((stateUpdate) =>
              print('SERVICE: connectToDevice state update: $stateUpdate'));
    }
  }

  @override
  void disconnect(Device device) {
    if (_connectionStreams.containsKey(device.id)) {
      if (_connectionStreams[device.id].isNullOrBlank ||
          _connectionStreams[device.id].isPaused)
        throw Exception(
            'SERVICE: Connection stream is paused or null or blank! It cannot be canceled =============');
      _connectionStreams[device.id].cancel();
      _connectionStreams.remove(device.id);
    } else {
      throw Exception(
          'SERVICE: Connection stream not found in the _connectionStreams list for ${device.id}');
    }
  }

  @override
  void onClose() {
    _ble.deinitialize();
    super.onClose();
  }

  /// Keep track of connected devices count and update the isConnected stream.
  void _handleConnectionStateUpdates(ConnectionStateUpdate stateUpdate) {
    print('SERVICE: connectedDeviceStream update: $stateUpdate');
    String deviceId = stateUpdate.deviceId;
    ble.DeviceConnectionState connectionState = stateUpdate.connectionState;

    // Device connected.
    if (connectionState == ble.DeviceConnectionState.connected) {
      _connectedDevicesCount++;
      if (_connectedDevicesCount == 1) _isConnected.value = true;

      // Add to connected devices and remove from scanned devices.
      int deviceIndex =
          _scannedDevices.indexWhere((device) => device.id == deviceId);
      if (deviceIndex != -1) {
        _connectedDevices.add(_scannedDevices[deviceIndex]);
        _scannedDevices.removeAt(deviceIndex);
      } else {
        if (_deviceConnectingTo.isNull) {
          // TODO: Get the name from the caracteristic
          _connectedDevices.add(Device(id: deviceId, name: 'Name pending...'));
        } else {
          if (_connectedDevices
                  .indexWhere((_device) => _device.id == deviceId) ==
              -1) {
            print('SERVICE: Adding connected device to the list');
            _connectedDevices.add(_deviceConnectingTo);
          } else
            print(
                'SERVICE: Connected device already in list, this shouldn\'t happen! ================');
        }
      }

      if (!_deviceConnectingTo.isNull) {
        print('SERVICE: Clearing _deviceConnectingTo (after connecting)');
        _deviceConnectingTo = null;
      }

      // Subscribe to connection stream if not subbed yet (usually after restart).
      if (!_connectionStreams.containsKey(deviceId)) {
        print(
            'SERVICE: Probably performed a hot restart after being connected to a device, reconnecting to it');
        connect(Device(id: deviceId));
      }

      // Device disconnected.
    } else if (connectionState == ble.DeviceConnectionState.disconnected) {
      if (!_deviceConnectingTo.isNull && deviceId == _deviceConnectingTo.id) {
        print(
            'SERVICE: Clearing _deviceConnectingTo (after disconnected) -------');
        _deviceConnectingTo = null;
      }

      // Remove connection stream, if it exists.
      if (!_connectionStreams[deviceId].isNull) {
        print(
            'SERVICE: Removing connection stream (this should appear only after unsuccessful connect or unexpected disconnect)');
        _connectionStreams[deviceId].cancel();
        _connectionStreams.remove(deviceId);
      }

      if (_connectedDevicesCount > 0) {
        _connectedDevicesCount--;
        if (_connectedDevicesCount == 0) _isConnected.value = false;
      }

      // Move from list of scanned devices to connected devices, if needed.
      int deviceIndex =
          _connectedDevices.indexWhere((device) => device.id == deviceId);
      if (deviceIndex != -1) {
        _scannedDevices.add(_connectedDevices[deviceIndex]);
        _connectedDevices.removeAt(deviceIndex);
      }
    }

    // Update connection state of the Device model
    try {
      Device device = _scannedDevices.firstWhere(
          (device) => device.id == deviceId,
          orElse: () =>
              _connectedDevices.firstWhere((device) => device.id == deviceId));
      _setConnectionState(device, connectionState);
      if (_connectedDevices.contains(device))
        _connectedDevices.refresh();
      else
        _scannedDevices.refresh();
    } catch (StateError) {
      if (connectionState == ble.DeviceConnectionState.disconnected)
        print(
            'SERVICE: Device neither scanned, nor connected to! ---------------');
    }
  }

  /// Adds a [device] to a private list of discovered devices, unless already added.
  /// Also converts the DiscoveredDevice type into a custom Device type.
  /// Returns true if added, otherwise false.
  bool _addScanResult(DiscoveredDevice device) {
    for (Device _device in _scannedDevices)
      if (_device.id == device.id) return false;
    if (_connectionStreams.containsKey(device.id)) {
      print(
          'SERVICE: The connected device is scanned anyways ===================');
      return false;
    }

    var newDevice = Device(id: device.id, name: device.name);
    _scannedDevices.add(newDevice);
    print('SERVICE: Adding $newDevice!');
    return true;
  }

  /// Sets the connection state of a [device] to [connectionState].
  /// Performs a conversion of flutter_reactive_ble's DeviceConnectionState enum
  /// to Device's DeviceConnectionState enum.
  void _setConnectionState(
      Device device, ble.DeviceConnectionState connectionState) {
    switch (connectionState) {
      case ble.DeviceConnectionState.connecting:
        device.connectionState = DeviceConnectionState.connecting;
        break;
      case ble.DeviceConnectionState.connected:
        device.connectionState = DeviceConnectionState.connected;
        break;
      case ble.DeviceConnectionState.disconnecting:
        device.connectionState = DeviceConnectionState.disconnecting;
        break;
      case ble.DeviceConnectionState.disconnected:
        device.connectionState = DeviceConnectionState.disconnected;
        break;
    }
  }
}
