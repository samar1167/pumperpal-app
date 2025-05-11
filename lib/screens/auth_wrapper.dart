import 'package:flutter/material.dart';
import 'package:ppal/screens/login_screen.dart';
import 'package:ppal/screens/device_list_screen.dart';
import 'package:ppal/services/auth_service.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final bool isLoggedIn = snapshot.data ?? false;
        
        if (isLoggedIn) {
          return DeviceListScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}