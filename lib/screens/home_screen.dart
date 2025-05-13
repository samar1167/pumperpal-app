import 'package:flutter/material.dart';
import 'package:ppal/services/auth_service.dart';
import 'login_screen.dart';
import 'device_list_screen.dart';
import 'service_request_screen.dart';
import 'plan_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ppal/common.dart';
import 'package:ppal/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _userName;
  String? _userRole;
  bool _isLoggedIn = false;
  bool _isLoading = true;
  int _notificationCount = 0; // Add this variable

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    String? userName;
    String? userRole;

    if (isLoggedIn) {
      // Try to get the user's profile information
      try {
        final userInfo = await AuthService.getUserInfo();
        userName = userInfo['name'] ?? userInfo['email'];
        userRole = userInfo['role'];

        // Fetch notification count if logged in
        await _fetchNotificationCount();
      } catch (e) {
        print('Error fetching user info: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isLoggedIn = isLoggedIn;
        _userName = userName;
        _userRole = userRole;
        _isLoading = false;
      });
    }
  }

  // Add this method to fetch notification count
  Future<void> _fetchNotificationCount() async {
    try {
      final token = await AuthService.getAuthToken();
      if (token == null) return;

      final baseUrl = Config.backendUrl;
      final apiUrl = '$baseUrl/notifications/unread/count/';

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _notificationCount = data['count'] ?? 0;
          });
        }
      }
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 3 : 2;

    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            'PumperPal',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF388E3C),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFC8E6C9), Color(0xFFA5D6A7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.count(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _buildCard(
                context,
                title: 'My Device(s)',
                icon: Icons.devices,
                onTap: () async {
                  // Check if user is logged in before navigating
                  final isLoggedIn = await AuthService.isLoggedIn();
                  if (!isLoggedIn) {
                    if (context.mounted) {
                      _showLoginRequiredDialog(context, 'view your devices');
                    }
                    return;
                  }

                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DeviceListScreen(),
                      ),
                    );
                  }
                },
              ),
              _buildCard(
                context,
                title: 'Service Request',
                icon: Icons.build,
                onTap: () async {
                  // Check if user is logged in before navigating
                  final isLoggedIn = await AuthService.isLoggedIn();
                  if (!isLoggedIn) {
                    if (context.mounted) {
                      _showLoginRequiredDialog(context, 'submit a service request');
                    }
                    return;
                  }

                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ServiceRequestScreen(),
                      ),
                    );
                  }
                },
              ),
              _buildCard(
                context,
                title: 'Plans',
                icon: Icons.diamond_outlined,
                onTap: () async {
                  // Check if user is logged in before navigating
                  final isLoggedIn = await AuthService.isLoggedIn();
                  if (!isLoggedIn) {
                    if (context.mounted) {
                      _showLoginRequiredDialog(context, 'view available plans');
                    }
                    return;
                  }

                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PlanScreen(),
                      ),
                    );
                  }
                },
              ),
              _buildAccountCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context) {
    if (_isLoading) {
      // Show loading spinner while checking login status
      return _buildCard(
        context,
        title: 'Loading...',
        icon: Icons.hourglass_empty,
        onTap: () {}, // No action while loading
        customChild: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return _buildCard(
      context,
      title: _isLoggedIn ? '' : 'Account',
      icon: Icons.account_circle,
      onTap: () {
        // Navigate to the profile screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        ).then((_) {
          // Refresh the home screen when returning from profile screen
          _checkLoginStatus();
        });
      },
      customChild: _isLoggedIn ? Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_circle, size: 40, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            'Hello, ${_userName?.split(' ').first ?? 'User'}!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Role: ${_userRole ?? 'Unknown'}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'View Profile',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ],
      ) : null,
    );
  }

  void _showLoginRequiredDialog(BuildContext context, String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: Text('Please log in to $action.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
              ).then((_) {
                // Refresh login status after returning from login screen
                _checkLoginStatus();
              });
            },
            child: const Text('Login'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF388E3C),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await AuthService.logout();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged out successfully')),
                );
                // Refresh login status
                _checkLoginStatus();
              }
            },
            child: const Text('Logout'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context,
      {required String title,
      required IconData icon,
      required VoidCallback onTap,
      Widget? customChild}) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFA5D6A7), Color(0xFF81C784)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: customChild ?? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.white),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
