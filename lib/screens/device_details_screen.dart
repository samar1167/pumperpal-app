import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ppal/services/auth_service.dart';
import 'package:ppal/common.dart';
import 'package:intl/intl.dart';

class DeviceDetailsScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final Map<String, dynamic> device;

  const DeviceDetailsScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.device,
  });

  @override
  State<DeviceDetailsScreen> createState() => _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends State<DeviceDetailsScreen> {
  bool isLoadingDevice = false;
  bool isLoadingEvents = false;
  Map<String, dynamic>? deviceDetails;
  List<Map<String, dynamic>> events = [];
  String? deviceErrorMessage;
  String? eventsErrorMessage;

  @override
  void initState() {
    super.initState();
    // Initialize with the passed device data
    deviceDetails = widget.device;
    // Fetch the latest device details and events
    _fetchDeviceDetails();
    _fetchDeviceEvents();
  }

  Future<void> _fetchDeviceDetails() async {
    setState(() {
      isLoadingDevice = true;
      deviceErrorMessage = null;
    });

    try {
      final token = await AuthService.getAuthToken();
      if (token == null) {
        setState(() {
          deviceErrorMessage = 'Authentication token missing';
          isLoadingDevice = false;
        });
        return;
      }

      final baseUrl = Config.backendUrl;
      final apiUrl = '$baseUrl/devices/${widget.deviceId}/';

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
          deviceDetails = data;
          isLoadingDevice = false;
        });
      } else {
        setState(() {
          deviceErrorMessage = 'Failed to load device details: ${response.reasonPhrase}';
          isLoadingDevice = false;
        });
      }
    } catch (e) {
      print('Error fetching device details: $e');
      setState(() {
        deviceErrorMessage = 'Oops! There was an error. Please try again later.';
        isLoadingDevice = false;
      });
    }
  }

  Future<void> _fetchDeviceEvents() async {
    setState(() {
      isLoadingEvents = true;
      eventsErrorMessage = null;
    });

    try {
      final token = await AuthService.getAuthToken();
      if (token == null) {
        setState(() {
          eventsErrorMessage = 'Authentication token missing';
          isLoadingEvents = false;
        });
        return;
      }

      final baseUrl = Config.backendUrl;
      final apiUrl = '$baseUrl/devices/device_events/?device_id=${widget.deviceId}&limit=10';

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
          // Handle different possible response formats
          if (responseData is Map<String, dynamic> && responseData.containsKey('device_events')) {
            final List<dynamic> eventsList = responseData['device_events'];
            events = eventsList.map((event) => 
              Map<String, dynamic>.from(event)
            ).toList();
          } else if (responseData is Map<String, dynamic> && responseData.containsKey('results')) {
            final List<dynamic> eventsList = responseData['results'];
            events = eventsList.map((event) => 
              Map<String, dynamic>.from(event)
            ).toList();
          } else if (responseData is List<dynamic>) {
            events = responseData.map((event) => 
              Map<String, dynamic>.from(event)
            ).toList();
          } else {
            eventsErrorMessage = 'Unexpected response format from API';
          }
          isLoadingEvents = false;
        });
      } else {
        setState(() {
          eventsErrorMessage = 'Failed to load device events: ${response.reasonPhrase}';
          isLoadingEvents = false;
        });
      }
    } catch (e) {
      print('Error fetching device events: $e');
      setState(() {
        eventsErrorMessage = 'Oops! There was an error. Please try again later.';
        isLoadingEvents = false;
      });
    }
  }

  void _refreshAll() {
    _fetchDeviceDetails();
    _fetchDeviceEvents();
  }

  @override
  Widget build(BuildContext context) {
    // Extract site data if available
    Map<String, dynamic>? site = deviceDetails != null && 
                                 deviceDetails!['site'] is Map ? 
                                 deviceDetails!['site'] as Map<String, dynamic> : 
                                 null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.deviceName,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF388E3C),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
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
        child: _buildContent(site),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic>? site) {
    if (isLoadingDevice && deviceDetails == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF388E3C)),
        ),
      );
    }

    if (deviceErrorMessage != null && deviceDetails == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              deviceErrorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchDeviceDetails,
              child: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF388E3C),
              ),
            ),
          ],
        ),
      );
    }

    if (deviceDetails == null) {
      return const Center(
        child: Text('No device information available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Device Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const Divider(),
                  _buildInfoRow('Serial Number', deviceDetails!['serial_number']?.toString() ?? 'N/A'),
                  _buildInfoRow('Model', deviceDetails!['model']?.toString() ?? 'N/A'),
                  _buildInfoRow('Status', deviceDetails!['status']?.toString() ?? 'N/A'),
                  if (deviceDetails!['firmware_version'] != null)
                    _buildInfoRow('Firmware Version', deviceDetails!['firmware_version']?.toString() ?? 'N/A'),
                  if (deviceDetails!['last_active'] != null)
                    _buildInfoRow('Last Active', deviceDetails!['last_active']?.toString() ?? 'N/A'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          if (site != null)
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Location Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const Divider(),
                    if (site['name'] != null) 
                      _buildInfoRow('Name', site['name']?.toString() ?? 'N/A'),
                    _buildInfoRow('Address', site['address']?.toString() ?? 'N/A'),
                    _buildInfoRow('City', site['city']?.toString() ?? 'N/A'),
                    _buildInfoRow('State', site['state']?.toString() ?? 'N/A'),
                    if (site['zip_code'] != null) 
                      _buildInfoRow('Zip Code', site['zip_code']?.toString() ?? 'N/A'),
                  ],
                ),
              ),
            ),
            
          const SizedBox(height: 16),

          // Events section
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Device Events',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      if (isLoadingEvents)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF388E3C)),
                          ),
                        ),
                    ],
                  ),
                  const Divider(),
                  _buildEventsList(),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          if (isLoadingDevice) 
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF388E3C)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    if (isLoadingEvents && events.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF388E3C)),
          ),
        ),
      );
    }

    if (eventsErrorMessage != null && events.isEmpty) {
      return Column(
        children: [
          Text(
            eventsErrorMessage!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _fetchDeviceEvents,
            child: const Text('Try Again'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF388E3C),
            ),
          ),
        ],
      );
    }

    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No events recorded for this device.'),
      );
    }

    return SizedBox(
      height: 350, // Fixed height for the events list
      child: ListView.builder(
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          final timestamp = _formatDateTime(event['created_on']?.toString() ?? '');
          final data = event['data']?.toString() ?? 'Unknown';
          final status = event['status']?.toString() ?? 'No status';
          final severity = event['status']?.toString()?.toLowerCase() ?? 'info';

          Color severityColor;
          switch (severity) {
            case 'critical':
              severityColor = Colors.red;
              break;
            case 'warning':
              severityColor = Colors.orange;
              break;
            case 'info':
              severityColor = Colors.blue;
              break;
            default:
              severityColor = Colors.grey;
          }

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: Colors.white,
            child: ListTile(
              leading: Icon(
                _getEventIcon(data),
                color: severityColor,
                size: 36,
              ),
              title: Text(
                data,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(status),
                  const SizedBox(height: 4),
                  Text(
                    timestamp,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
  
  IconData _getEventIcon(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'error':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      case 'maintenance':
        return Icons.build;
      case 'status':
        return Icons.info;
      case 'connection':
        return Icons.signal_wifi_4_bar;
      case 'power':
        return Icons.power;
      case 'update':
        return Icons.system_update;
      case 'startup':
        return Icons.play_circle_filled;
      case 'shutdown':
        return Icons.power_settings_new;
      default:
        return Icons.event_note;
    }
  }
  
  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM d, yyyy - h:mm a').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
