import 'package:bletest/screens/home_controller.dart';
import 'package:bletest/screens/home_view.dart';
import 'package:get/get.dart';

List<GetPage> routes = [
  GetPage(
    name: 'home',
    page: () => HomeView(),
    binding: BindingsBuilder(() => Get.lazyPut(() => HomeController())),
  ),
];
