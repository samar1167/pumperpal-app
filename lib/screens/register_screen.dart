import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ppal/common.dart';
import 'package:ppal/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _passwordError;

  Future<void> _handleRegister() async {
    // First validate passwords match
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _passwordError = "Passwords don't match";
      });
      return;
    } else {
      setState(() {
        _passwordError = null;
      });
    }

    // Validate input fields
    if (_nameController.text.isEmpty || 
        _emailController.text.isEmpty || 
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final baseUrl = Config.backendUrl;
    final apiUrl = '$baseUrl/users/register/';
    final requestBody = {
      'name': _nameController.text,
      'email': _emailController.text,
      'username': _emailController.text,
      'password': _passwordController.text,
    };

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        
        // Auto-login after registration by saving the token
        if (responseData['token'] != null && responseData['user_id'] != null) {
          await AuthService.saveAuthToken(
            responseData['token'], 
            responseData['user_id'].toString()
          );
          
          // Register device with the server
          await _registerDevice(responseData['token']);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful! You are now logged in.')),
          );
        } else {
          // If no token is returned, just show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful! Please log in.')),
          );
        }
        
        Navigator.pop(context, true); // Return true to indicate successful registration
      } else {
        // Try to parse error messages from the response
        try {
          final errorData = jsonDecode(response.body);
          String errorMessage = 'Registration failed';
          
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          } else if (errorData['error'] != null) {
            errorMessage = errorData['error'];
          } else if (errorData['detail'] != null) {
            errorMessage = errorData['detail'];
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration failed: ${response.reasonPhrase}')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Add this method to register device after successful registration
  Future<void> _registerDevice(String authToken) async {
    try {
      // Get the stored FCM token
      final prefs = await SharedPreferences.getInstance();
      final fcmToken = prefs.getString('fcm_token');
      if (fcmToken == null || fcmToken.isEmpty) return;
      
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = '';
      String deviceModel = '';
      
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id ?? 'unknown-android';
        deviceModel = androidInfo.model ?? 'Unknown Android Device';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown-ios';
        deviceModel = iosInfo.utsname.machine ?? 'Unknown iOS Device';
      }
      
      final baseUrl = Config.backendUrl;
      final apiUrl = '$baseUrl/notifications/mobile/register/';
      
      await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          "token": fcmToken,
          "platform": Platform.isIOS ? "ios" : "android",
        }),
      );
      
      print("Device registered successfully after registration");
    } catch (e) {
      print("Error registering device: $e");
      // Don't fail the registration if device registration fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Register',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF388E3C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                border: const OutlineInputBorder(),
                errorText: _passwordError,
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF388E3C),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text(
                      'Register',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}