import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:ppal/screens/splash_screen.dart';


// void main() async {
//   // Ensure Flutter is initialized
//   WidgetsFlutterBinding.ensureInitialized();
//
//   runApp(const MyApp());
// }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Optional: Initialize Firebase
  // await Firebase.initializeApp();
  // FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('Flutter Error: ${details.exception}');
    // FirebaseCrashlytics.instance.recordFlutterError(details);
  };

  runZonedGuarded(() async {
    runApp(MyApp());
  }, (Object error, StackTrace stackTrace) {
    print('Zoned Error: $error');
    // FirebaseCrashlytics.instance.recordError(error, stackTrace);
  });
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _deviceModel = 'Unknown';

  @override
  void initState() {
    super.initState();
    _initPermissions();
    _getDeviceInfo();
    print ("SAM 1: $_deviceModel");
  }

  Future<void> _initPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
      Permission.storage, // or Permission.photos on iOS
    ].request();
  }

  Future<void> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      setState(() {
        _deviceModel = androidInfo.model ?? 'Unknown Android Device';
      });
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      setState(() {
        _deviceModel = iosInfo.utsname.machine ?? 'Unknown iOS Device';
      });
    }
  }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Device: $_deviceModel',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(), // Start with SplashScreen instead of HomeScreen
    );
  }
}
