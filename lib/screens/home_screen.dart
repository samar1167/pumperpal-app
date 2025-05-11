import 'package:flutter/material.dart';
import 'package:ppal/services/auth_service.dart';
import 'login_screen.dart';
import 'device_list_screen.dart';
import 'service_request_screen.dart';
import 'plan_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 3 : 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PumperPal Home'),
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
      return Card(
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
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    if (_isLoggedIn) {
      return GestureDetector(
        onTap: () {
          _showLogoutConfirmDialog(context);
        },
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
            child: Column(
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
                  'Account Settings',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return _buildCard(
        context,
        title: 'Login',
        icon: Icons.login,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            ),
          ).then((_) {
            // Refresh the login status when returning from the login screen
            _checkLoginStatus();
          });
        },
      );
    }
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
      required VoidCallback onTap}) {
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
          child: Column(
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
