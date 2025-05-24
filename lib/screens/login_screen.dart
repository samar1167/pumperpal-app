import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ppal/services/auth_service.dart';
import 'package:ppal/screens/device_list_screen.dart';
// Import the register screen
import 'package:ppal/screens/register_screen.dart';
import 'package:ppal/common.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    final email = _usernameController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final baseUrl = Config.backendUrl;
      final apiUrl = '$baseUrl/users/login/';
      final requestBody = {
        'username': email,
        'password': password,
      };

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        // Save token and user ID
        await AuthService.saveAuthToken(
          responseData['token'], 
          responseData['user_id'].toString()
        );
        
        // After successful login, register the device
        await _registerDevice(responseData['token']);
        
        // Return true to the calling screen to indicate successful login
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${response.reasonPhrase ?? "Invalid credentials"}')),
        );
      }
    } catch (e) {
      print ("Error during login: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Oops! There was an error. Please try again later.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Add this method to register device after successful login
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
      
      print("Device registered successfully after login");
    } catch (e) {
      print("Error registering device: $e");
      // Don't fail the login if device registration fails
    }
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Login',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF388E3C),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
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
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF388E3C),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account?"),
                TextButton(
                  onPressed: _navigateToRegister,
                  child: const Text(
                    'Register',
                    style: TextStyle(
                      color: Color(0xFF388E3C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}