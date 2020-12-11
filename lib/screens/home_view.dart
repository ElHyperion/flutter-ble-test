import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bletest/models/device.dart';

import 'home_controller.dart';

class HomeView extends GetView<HomeController> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Bluetooth connections')),
        floatingActionButton: Obx(() => controller.isScanning.value
            ? FloatingActionButton(
                child: Icon(Icons.stop),
                backgroundColor: Colors.red,
                onPressed: controller.onScan)
            : FloatingActionButton(
                child: Icon(Icons.search),
                backgroundColor: Colors.blue,
                tooltip: 'Start/stop scan',
                onPressed: controller.onScan)),
        body: Stack(children: <Widget>[
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Obx(
                  () {
                    IconData icon;
                    String text = '';
                    switch (controller.btIconState.value) {
                      case BluetoothIconState.on:
                        if (controller.scannedDevices.length == 0 &&
                            controller.connectedDevices.length == 0) {
                          icon = Icons.bluetooth;
                          text = 'No devices';
                        }
                        break;
                      case BluetoothIconState.scanning:
                        icon = Icons.bluetooth_searching;
                        text = 'Scanning...';
                        break;
                      default: // Off, unauthorized, unavailable, unknown
                        icon = Icons.bluetooth_disabled;
                        text = 'Bluetooth is turned off';
                        break;
                    }
                    return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            icon,
                            color: Colors.grey.withOpacity(0.25),
                            size: 300,
                          ),
                          Text(text, style: TextStyle(color: Colors.grey)),
                        ]);
                  },
                ),
              ],
            ),
          ),
          Obx(() {
            List<Widget> deviceWidgets = [];
            if (controller.connectedDevices.length > 0) {
              deviceWidgets.add(ListTile(title: Text('Connected')));
              for (Device device in controller.connectedDevices) {
                deviceWidgets.add(_Device(device: device));
              }
            }
            if (controller.scannedDevices.length > 0) {
              deviceWidgets.add(ListTile(title: Text('Scanned')));
              for (Device device in controller.scannedDevices) {
                deviceWidgets.add(_Device(device: device));
              }
            }
            return ListView(
              primary: false,
              children: deviceWidgets,
              shrinkWrap: true,
              physics: ClampingScrollPhysics(),
            );
          })
        ]));
  }
}

class _Device extends GetView<HomeController> {
  final Device device;

  _Device({this.device});

  @override
  Widget build(BuildContext context) {
    VoidCallback onPressed;
    String text = '';

    switch (device.connectionState) {
      case DeviceConnectionState.connecting:
        text = 'Connecting...';
        break;
      case DeviceConnectionState.connected:
        text = 'Disconnect';
        onPressed = () => controller.onDisconnect(device);
        break;
      case DeviceConnectionState.disconnecting:
        text = 'Disconnecting...';
        break;
      case DeviceConnectionState.disconnected:
        text = 'Connect';
        onPressed = () => controller.onConnect(device);
        break;
    }

    return Container(
        child: ListTile(
            leading: FlutterLogo(),
            title: Text(device.name ?? 'Unknown name'),
            subtitle: Text('${device.id}'),
            trailing: RaisedButton(child: Text(text), onPressed: onPressed)));
  }
}
