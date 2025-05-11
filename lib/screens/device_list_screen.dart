import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'device_details_screen.dart';
import 'package:ppal/services/auth_service.dart';
import 'package:ppal/common.dart';
import 'package:ppal/screens/login_screen.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  List<Map<String, dynamic>> devices = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  Future<void> _fetchDevices() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final token = await AuthService.getAuthToken();
      if (token == null) {
        // Handle case where token is missing
        _handleLogout(context);
        return;
      }

      final baseUrl = Config.backendUrl;
      final apiUrl = '$baseUrl/devices/';

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        setState(() {
          // Check if the response is a map with a 'devices' or similar field
          if (responseData is Map<String, dynamic> && responseData.containsKey('devices')) {
            // If the API returns {devices: [...]}
            final List<dynamic> devicesList = responseData['devices'];
            devices = devicesList.map((device) => 
              Map<String, dynamic>.from(device)
            ).toList();
          } else if (responseData is Map<String, dynamic> && responseData.containsKey('results')) {
            // If the API returns {results: [...]}
            final List<dynamic> devicesList = responseData['results'];
            devices = devicesList.map((device) => 
              Map<String, dynamic>.from(device)
            ).toList();
          } else if (responseData is List<dynamic>) {
            // If the API directly returns a list [...]
            devices = responseData.map((device) => 
              Map<String, dynamic>.from(device)
            ).toList();
          } else {
            // If we can't identify the structure, show an error
            errorMessage = 'Unexpected response format from API';
          }
          isLoading = false;
        });
      } else if (response.statusCode == 401) {
        // Handle unauthorized (expired token)
        _handleLogout(context);
      } else {
        setState(() {
          errorMessage = 'Failed to load devices: ${response.reasonPhrase}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  void _handleLogout(BuildContext context) async {
    await AuthService.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Device(s)',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF388E3C),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDevices,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFC8E6C9), Color(0xFFA5D6A7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF388E3C)),
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchDevices,
              child: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF388E3C),
              ),
            ),
          ],
        ),
      );
    }

    if (devices.isEmpty) {
      return const Center(
        child: Text(
          'No devices found',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDevices,
      color: const Color(0xFF388E3C),
      child: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          // Extract site data if available
          Map<String, dynamic>? site = device['site'] is Map ? device['site'] as Map<String, dynamic> : null;
          
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeviceDetailsScreen(
                    deviceId: device['id']?.toString() ?? '',
                    deviceName: device['serial_number']?.toString() ?? 'Unknown Device',
                    device: device, // Pass the full device object for complete access to data
                  ),
                ),
              ).then((_) => _fetchDevices()); // Refresh after returning to update any changes
            },
            child: Card(
              elevation: 5,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            device['serial_number'] ?? 'Unknown Device',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            device['status'] ?? 'Unknown',
                            style: const TextStyle(
                              color: Color(0xFF388E3C),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (site != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            site['name'] ?? '',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            "${site['address'] ?? ''}, ${site['city'] ?? ''}, ${site['state'] ?? ''}",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
