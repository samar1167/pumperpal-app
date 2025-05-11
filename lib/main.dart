import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ppal/screens/home_screen.dart';
// import 'package:flutter_stripe/flutter_stripe.dart';


void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    print ("SAM 1: In Web");
    // Config.stripePublishableKey = html.document.head!.querySelector('meta[name="api-key"]')?.content ?? '';
  } else {
    print ("SAM 2: In Mobile");
    // await dotenv.load();
  }
  
  // Load environment variables
  print ("${Directory.current.path}/.env");
  // await dotenv.load(fileName: "${Directory.current.path}/.env");
  // await dotenv.load();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PumperPal',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(), // Always start with HomeScreen
    );
  }
}
