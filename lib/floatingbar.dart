import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';

class FloatingBar {
  static const _animDuration = Duration(milliseconds: 400);
  static const _duration = Duration(seconds: 2);
  static const double _iconSize = 30;

  static void infoBar({String message = '', Duration duration = _duration}) {
    Get.rawSnackbar(
      icon: Icon(
        Icons.info,
        color: Colors.blue[300],
        size: _iconSize,
      ),
      leftBarIndicatorColor: Colors.blue[300],
      message: message,
      animationDuration: _animDuration,
      duration: _duration,
    );
  }

  static void alertBar({String message = '', Duration duration = _duration}) {
    Get.rawSnackbar(
      icon: Icon(
        Icons.warning,
        color: Colors.red[300],
        size: _iconSize,
      ),
      leftBarIndicatorColor: Colors.red[300],
      message: message,
      animationDuration: _animDuration,
      duration: _duration,
    );
  }
}
