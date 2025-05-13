import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ppal/common.dart';
import 'package:ppal/services/auth_service.dart';
import 'package:ppal/screens/login_screen.dart';
import 'package:ppal/screens/register_screen.dart';

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
  bool _isLoadingMoreNotifications = false; // New variable for "Load More"
  String? _nextPageUrl; // Track the URL for the next page
  int _page = 1; // Track current page number

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

  // Update the notifications fetching method to handle pagination
  Future<void> _fetchNotifications({bool loadMore = false}) async {
    if (!_isLoggedIn) return;
    
    setState(() {
      if (loadMore) {
        _isLoadingMoreNotifications = true;
      } else {
        _isLoadingNotifications = true;
        _page = 1; // Reset page number for fresh loads
      }
    });

    try {
      final token = await AuthService.getAuthToken();
      if (token == null) {
        setState(() {
          _isLoadingNotifications = false;
          _isLoadingMoreNotifications = false;
        });
        return;
      }

      final baseUrl = Config.backendUrl;
      
      // Use next page URL if loading more, or construct initial URL
      final apiUrl = loadMore ? _nextPageUrl : '$baseUrl/notifications/?page=$_page';
      
      if (apiUrl == null) {
        // No more pages to load
        setState(() {
          _isLoadingMoreNotifications = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Check if there's a next page URL in the response
        _nextPageUrl = data['next'];
        
        List<Map<String, dynamic>> newNotifications = [];
        if (data is List) {
          newNotifications = List<Map<String, dynamic>>.from(data);
        } else if (data['results'] != null && data['results'] is List) {
          newNotifications = List<Map<String, dynamic>>.from(data['results']);
        }
        
        setState(() {
          if (loadMore) {
            // Add new notifications to existing list
            _notifications.addAll(newNotifications);
            _isLoadingMoreNotifications = false;
            _page++; // Increment page number
          } else {
            // Replace existing notifications
            _notifications = newNotifications;
            _isLoadingNotifications = false;
          }
        });
      } else {
        setState(() {
          if (!loadMore) {
            _notifications = [];
          }
          _isLoadingNotifications = false;
          _isLoadingMoreNotifications = false;
        });
      }
    } catch (e) {
      print('Error fetching notifications: $e');
      setState(() {
        if (!loadMore) {
          _notifications = [];
        }
        _isLoadingNotifications = false;
        _isLoadingMoreNotifications = false;
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
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Combined user info and actions card for non-logged in users
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Color(0xFF388E3C),
                      child: Icon(
                        Icons.account_circle,
                        size: 50,
                        color: Colors.white,
                      ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                            ).then((_) => _checkLoginStatus());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF388E3C),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: const Text(
                            'Login',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const RegisterScreen()),
                            ).then((_) => _checkLoginStatus());
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF388E3C)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: const Text(
                            'Register',
                            style: TextStyle(color: Color(0xFF388E3C), fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
          // Combined user info and account actions for logged-in users
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Padding(
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
                                'Thank you dear ${_userRole ?? 'User'}',
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
                const Divider(height: 1),
                InkWell(
                  onTap: _handleLogout,
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 10),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Notifications card remains separate
          _buildNotificationsCard(),
        ],
      ),
    );
  }

  Widget _buildNotificationsCard() {
    return Card(
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
            if (_isLoadingNotifications)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_notifications.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Center(
                  child: Text(
                    'No notifications',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Column(
                children: [
                  ..._notifications.map((notification) {
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
                  
                  // "Load More" button
                  if (_nextPageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Center(
                        child: _isLoadingMoreNotifications
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : ElevatedButton(
                                onPressed: () {
                                  _fetchNotifications(loadMore: true);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF388E3C),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                ),
                                child: const Text(
                                  'Load More',
                                  style: TextStyle(color: Colors.white),
                                ),
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

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }
}