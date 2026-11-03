import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app_starter/app.dart';
import 'package:app_starter/core/network/api_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 与 collection-app 相同：原生 LaunchScreen 一直盖到 allowFirstFrame，避免双闪屏
  WidgetsBinding.instance.deferFirstFrame();
  unawaited(ApiClient.warmup());
  runApp(const AppStarterApp());
}
