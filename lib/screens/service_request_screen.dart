import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

import 'package:ppal/services/auth_service.dart';
import 'package:ppal/common.dart';
import "package:ppal/screens/add_address_screen.dart";
import "package:ppal/screens/service_request_detail_screen.dart";

class ServiceRequestScreen extends StatefulWidget {
  const ServiceRequestScreen({super.key});

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  bool _isLoadingRequests = true;
  List<Map<String, dynamic>> _serviceRequests = [];
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _fetchServiceRequests();
  }

  Future<void> _fetchServiceRequests() async {
    setState(() {
      _isLoadingRequests = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthService.getAuthToken();
      if (token == null) {
        setState(() {
          _errorMessage = 'Authentication token missing. Please log in.';
          _isLoadingRequests = false;
        });
        return;
      }

      final baseUrl = Config.backendUrl;
      final apiUrl = '$baseUrl/service_request/';

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        List<dynamic> requestsList = [];
        
        // Handle different response formats
        if (responseData is Map<String, dynamic> && responseData.containsKey('service_requests')) {
          requestsList = responseData['service_requests'];
        } else if (responseData is Map<String, dynamic> && responseData.containsKey('results')) {
          requestsList = responseData['results'];
        } else if (responseData is List<dynamic>) {
          requestsList = responseData;
        }
        
        setState(() {
          _serviceRequests = requestsList.map((request) => Map<String, dynamic>.from(request)).toList();
          _isLoadingRequests = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load service requests: ${response.reasonPhrase}';
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoadingRequests = false;
      });
    }
  }

  void _navigateToNewRequestForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NewServiceRequestScreen(),
      ),
    ).then((_) => _fetchServiceRequests()); // Refresh after returning
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM d, yyyy - h:mm a').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return Colors.purple;
      case 'pending':
        return Colors.blue;
      case 'in progress':
        return Colors.orange;
      case 'pending payment':
        return Colors.red;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Service Requests',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF388E3C),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchServiceRequests,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToNewRequestForm,
        backgroundColor: const Color(0xFF388E3C),
        child: const Icon(Icons.add),
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
    if (_isLoadingRequests) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF388E3C)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchServiceRequests,
              child: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF388E3C),
              ),
            ),
          ],
        ),
      );
    }

    if (_serviceRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No service requests found',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _navigateToNewRequestForm,
              icon: const Icon(Icons.add),
              label: const Text('Create New Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF388E3C),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchServiceRequests,
      color: const Color(0xFF388E3C),
      child: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: _serviceRequests.length,
        itemBuilder: (context, index) {
          final request = _serviceRequests[index];
          final status = request['status'] ?? 'Unknown';
          final title = request['title'] ?? 'Service Request ${request['id'] ?? (index + 1)}';
          Map<String, dynamic>? address = request['address'] is Map ? request['address'] as Map<String, dynamic> : null;
          
          return Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ExpansionTile(
              title: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (request['request_type'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Type: ${request['request_type']}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    if (request['description'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                        'Description: ${request['description'] != null && request['description'].length > 100 ? '${request['description'].substring(0, 100)}...' : request['description'] ?? ''}',
                        style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  Row(
                    children: [
                      Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      margin: const EdgeInsets.only(top: 4, right: 8),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        ),
                      ),
                      ),
                      Expanded(
                      child: Text(
                        _formatDateTime(request['created_at']?.toString()),
                        style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        ),
                      ),
                      ),
                    ],
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Description:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request['description'] ?? 'No description provided',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      
                      if (address != null) ...[
                        const Text(
                          'Service Address:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('${address['address']}, ${address['city']}, ${address['state']}, ${address['zipcode']}'),
                        const SizedBox(height: 12),
                      ],
                      
                      const SizedBox(height: 8),
                      if (request['scheduled_date'] != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Scheduled At:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDateTime('${request['scheduled_date']} ${request['scheduled_time']}'),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                            builder: (context) => ServiceRequestDetailsScreen(
                              serviceRequestId: request['id'].toString(),
                              serviceRequest: request,
                            ),
                            ),
                          );
                          },
                          style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF388E3C),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          ),
                          child: const Text(
                          'View Details',
                          style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Create a separate screen for creating new service requests
class NewServiceRequestScreen extends StatefulWidget {
  const NewServiceRequestScreen({super.key});

  @override
  State<NewServiceRequestScreen> createState() => _NewServiceRequestScreenState();
}

class _NewServiceRequestScreenState extends State<NewServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _requestTypeController = TextEditingController(text: 'General');
  final _problemDescriptionController = TextEditingController();
  DateTime _selectedScheduledDate = DateTime.now();
  TimeOfDay _selectedScheduledTime = TimeOfDay.now();
  final _addressController = TextEditingController();
  final _requestTypeOptions = ['General', 'Technical'];
  String _selectedRequestType = 'General';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _requestTypeController.dispose();
    _problemDescriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submitServiceRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final token = await AuthService.getAuthToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to submit a service request')),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      final baseUrl = Config.backendUrl;
      final apiUrl = '$baseUrl/service_request/create/';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'request_type': _requestTypeController.text,
          'description': _problemDescriptionController.text,
          'address': _addressController.text,
          'scheduled_date': _selectedScheduledDate.toIso8601String().split('T').first,
          'scheduled_time': '${_selectedScheduledTime.hour.toString().padLeft(2, '0')}:${_selectedScheduledTime.minute.toString().padLeft(2, '0')}', // Time in HH:mm format
        }),
      );

      setState(() {
        _isSubmitting = false;
      });

      if (response.statusCode == 201) {
        _showSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit request: ${response.reasonPhrase}')),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: const Text('Your service request has been submitted successfully. Our team will respond shortly.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to service requests list
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<List<String>> _fetchAddresses() async {
    try {
      final token = await AuthService.getAuthToken();
      if (token == null) {
        throw Exception('Authentication token missing');
      }

      final baseUrl = Config.backendUrl;
      final apiUrl = '$baseUrl/sites/address/';

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        List<dynamic> addressesList = [];
        
        // Handle different response formats
        if (responseData is Map<String, dynamic> && responseData.containsKey('addresses')) {
          addressesList = responseData['addresses'];
        } else if (responseData is Map<String, dynamic> && responseData.containsKey('results')) {
          addressesList = responseData['results'];
        } else if (responseData is List<dynamic>) {
          addressesList = responseData;
        }
        
        return addressesList.map((addr) {
          if (addr is Map<String, dynamic>) {
            // Format the address as a string
            final id = addr['id'] ?? '';
            final address = addr['address'] ?? '';
            final city = addr['city'] ?? '';
            final state = addr['state'] ?? '';
            final zipcode = addr['zipcode'] ?? '';
            
            return '$id, $address, $city, $state $zipcode';
          }
          return addr.toString();
        }).toList();
      } else {
        throw Exception('Failed to load addresses: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error fetching addresses: $e');
      return [];
    }
  }

  void _navigateToAddAddressScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddAddressScreen(),
      ),
    ).then((_) {
      // This will refresh the addresses dropdown after returning from the add address screen
      setState(() {
        // Force rebuild of the FutureBuilder
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Service Request'),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 4.0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Create a Service Request',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    const Text(
                      'Request Type:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedRequestType,
                      items: _requestTypeOptions
                          .map((option) => DropdownMenuItem<String>(
                                value: option,
                                child: Text(option),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _requestTypeController.text = value!;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    const Text(
                      'Problem Description:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _problemDescriptionController,
                      decoration: const InputDecoration(
                        hintText: 'Describe the issue you are experiencing...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please describe the problem';
                        }
                        if (value.length < 10) {
                          return 'Description is too short';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    const Text(
                      'Service Address:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<String>>(
                      future: _fetchAddresses(), // Fetch addresses from API
                      builder: (context, snapshot) {
                        // Always show the "Add New Address" button regardless of connection state
                        Widget addressSelector;
                        
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          addressSelector = const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 10.0),
                              child: CircularProgressIndicator(),
                            )
                          );
                        } else if (snapshot.hasError) {
                          addressSelector = Text(
                            'Error loading addresses: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          );
                        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          addressSelector = const Text(
                            'No addresses available. Please add a new address.',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          );
                        } else {
                          // We have addresses to display
                          final addresses = snapshot.data!;
                          addressSelector = DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            value: _addressController.text.isNotEmpty ? _addressController.text : null,
                            items: addresses
                              .map((address) {
                                final parts = address.split(',');
                                final id = parts.isNotEmpty ? parts[0] : '';
                                final displayText = parts.length > 1 ? parts.sublist(1).join(',') : address;
                                return DropdownMenuItem<String>(
                                  value: id,
                                  child: Text(displayText.trim()),
                                );
                              })
                              .toList(),
                            onChanged: (value) {
                              setState(() {
                                _addressController.text = value!;
                              });
                            },
                            hint: const Text('Select an address'),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select or add an address';
                              }
                              return null;
                            },
                          );
                        }
                        
                        // Return a column with both the address selector and the Add New Address button
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            addressSelector,
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _navigateToAddAddressScreen,
                              icon: const Icon(Icons.add),
                              label: const Text('Add New Address'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF388E3C),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      const Text(
                        'Scheduled Date:',
                        style: TextStyle(
                        fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                        hintText: DateFormat('yyyy-MM-dd').format(_selectedScheduledDate),
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.calendar_today),
                        ),
                        onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedScheduledDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setState(() {
                          _selectedScheduledDate = pickedDate;
                          });
                        }
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Scheduled Time:',
                        style: TextStyle(
                        fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                        hintText: _selectedScheduledTime.format(context),
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.access_time),
                        ),
                        onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: _selectedScheduledTime,
                        );
                        if (pickedTime != null) {
                          setState(() {
                          _selectedScheduledTime = pickedTime;
                          });
                        }
                        },
                      ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    _isSubmitting
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _submitServiceRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF388E3C),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: const Text(
                              'Submit Request',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}