import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app_starter/app.dart';
import 'package:app_starter/core/network/api_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(ApiClient.warmup());
  runApp(const AppStarterApp());
}
