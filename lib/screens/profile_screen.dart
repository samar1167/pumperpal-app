import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ppal/common.dart';
import 'package:ppal/services/auth_service.dart';
import 'package:ppal/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _userName;
  String? _userEmail;
  String? _userRole;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoadingNotifications = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    setState(() {
      _isLoading = true;
    });

    final isLoggedIn = await AuthService.isLoggedIn();
    
    if (isLoggedIn) {
      try {
        final userInfo = await AuthService.getUserInfo();
        setState(() {
          _isLoggedIn = true;
          _userName = userInfo['name'];
          _userEmail = userInfo['email'];
          _userRole = userInfo['role'];
        });
        
        // Fetch notifications after user info is loaded
        await _fetchNotifications();
      } catch (e) {
        print('Error fetching user info: $e');
      }
    }

    setState(() {
      _isLoading = false;
      _isLoggedIn = isLoggedIn;
    });
  }

  Future<void> _fetchNotifications() async {
    if (!_isLoggedIn) return;
    
    setState(() {
      _isLoadingNotifications = true;
    });

    try {
      final token = await AuthService.getAuthToken();
      if (token == null) {
        setState(() {
          _isLoadingNotifications = false;
        });
        return;
      }

      final baseUrl = Config.backendUrl;
      final apiUrl = '$baseUrl/notifications/';

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          if (data is List) {
            _notifications = List<Map<String, dynamic>>.from(data);
          } else if (data['results'] != null && data['results'] is List) {
            _notifications = List<Map<String, dynamic>>.from(data['results']);
          } else {
            _notifications = [];
          }
          _isLoadingNotifications = false;
        });
      } else {
        setState(() {
          _notifications = [];
          _isLoadingNotifications = false;
        });
      }
    } catch (e) {
      print('Error fetching notifications: $e');
      setState(() {
        _notifications = [];
        _isLoadingNotifications = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      final token = await AuthService.getAuthToken();
      if (token == null) return;

      final baseUrl = Config.backendUrl;
      final apiUrl = '$baseUrl/notifications/$notificationId/read/';

      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        await _fetchNotifications();  // Refresh notifications
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF388E3C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFC8E6C9), Color(0xFFA5D6A7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildProfileContent(),
      ),
    );
  }

  Widget _buildProfileContent() {
    if (!_isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_circle,
              size: 80,
              color: Color(0xFF388E3C),
            ),
            const SizedBox(height: 20),
            const Text(
              'Not Logged In',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please log in to view your profile',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                ).then((_) => _checkLoginStatus());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF388E3C),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              child: const Text(
                'Login',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFF388E3C),
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName ?? 'User',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userEmail ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF388E3C).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Role: ${_userRole ?? 'User'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF388E3C),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Logout'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _handleLogout,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_notifications.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _notifications.length.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _isLoadingNotifications
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _notifications.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20.0),
                              child: Center(
                                child: Text(
                                  'No notifications',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          : Column(
                              children: _notifications.map((notification) {
                                final bool isUnread = notification['read'] == false;
                                return Dismissible(
                                  key: Key(notification['id'].toString()),
                                  background: Container(
                                    color: Colors.green,
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: const Icon(Icons.check, color: Colors.white),
                                  ),
                                  direction: DismissDirection.startToEnd,
                                  onDismissed: (_) {
                                    _markNotificationAsRead(notification['id'].toString());
                                  },
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
                                    leading: CircleAvatar(
                                      backgroundColor: isUnread ? Colors.red : Colors.grey,
                                      child: Icon(
                                        isUnread ? Icons.notifications_active : Icons.notifications,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Text(
                                      notification['title'] ?? 'Notification',
                                      style: TextStyle(
                                        fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(notification['message'] ?? ''),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDateTime(notification['created_at'] ?? ''),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                    isThreeLine: true,
                                    onTap: () {
                                      _markNotificationAsRead(notification['id'].toString());
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }
}