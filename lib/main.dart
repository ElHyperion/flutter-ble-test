import 'package:get/get.dart';
import 'package:flutter/material.dart';

import 'services/ble_service.dart';
import 'services/flutter_reactive_ble_service.dart';
import 'pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Get.put<BLEService>(FlutterReactiveBLE()).init();
  runApp(AppMain());
}

class AppMain extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GetMaterialApp(
      title: 'Reactive BLE test app', initialRoute: 'home', getPages: routes);
}
