import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ppal/services/auth_service.dart';
import 'package:ppal/common.dart';
import 'package:ppal/screens/payment_screen.dart';

class ServiceRequestDetailsScreen extends StatefulWidget {
  final String serviceRequestId;
  final Map<String, dynamic> serviceRequest;

  const ServiceRequestDetailsScreen({
    super.key,
    required this.serviceRequestId,
    required this.serviceRequest,
  });

  @override
  State<ServiceRequestDetailsScreen> createState() => _ServiceRequestDetailsScreenState();
}

class _ServiceRequestDetailsScreenState extends State<ServiceRequestDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _serviceRequestDetails;
  List<Map<String, dynamic>> _serviceNotes = [];
  List<Map<String, dynamic>> _attachments = [];
  String? _errorMessage;
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmittingNote = false;
  bool _isUploadingAttachment = false;
  bool _isSubmittingCancel = false;
  String? _userRole;
  bool _isEditing = false;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _scheduledDateController = TextEditingController();
  final TextEditingController _scheduledTimeController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String? _selectedRequestType;
  String? _selectedAddress;
  String? _selectedStatus;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _currentDownloadName;

  @override
  void initState() {
    super.initState();
    _serviceRequestDetails = widget.serviceRequest;
    _fetchServiceRequestDetails();
    _getUserRole();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _descriptionController.dispose();
    _scheduledDateController.dispose();
    _scheduledTimeController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchServiceRequestDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthService.getAuthToken();
      if (token == null) {
        print('Authentication token missing');
        setState(() {
          _errorMessage = 'Oops! There was an error. Please try again later.';
          _isLoading = false;
        });
        return;
      }

      final baseUrl = Config.backendUrl;
      final apiUrl = '$baseUrl/service_request/${widget.serviceRequestId}/';

      // First: fetch service request details
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Second: fetch attachments (regardless of first call result)
      final attachmentsUrl = '$baseUrl/service_request/${widget.serviceRequestId}/attachments/';
      final attachmentsResponse = await http.get(
        Uri.parse(attachmentsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200 || attachmentsResponse.statusCode != 200) {
        print('Failed to load service request details or attachments: ${response.reasonPhrase}');
        setState(() {
          _errorMessage = 'Oops! There was an error. Please try again later.';
          _isLoading = false;
        });
        return;
      }
      setState(() {
        final data = jsonDecode(response.body);
        _serviceRequestDetails = data;

        // Extract service notes if available
        if (data.containsKey('notes') && data['notes'] is List) {
          _serviceNotes = List<Map<String, dynamic>>.from(data['notes']);
        } else if (data.containsKey('service_notes') &&
            data['service_notes'] is List) {
          _serviceNotes =
          List<Map<String, dynamic>>.from(data['service_notes']);
        }

        // Extract attachments from the attachments API response
        if (attachmentsResponse.body.isNotEmpty) {
          final attachmentsData = jsonDecode(attachmentsResponse.body);
          if (attachmentsData is List) {
            _attachments = List<Map<String, dynamic>>.from(attachmentsData);
          }
        }

        _isLoading = false;
      });
    } catch (e) {
      print('Error: $e');
      setState(() {
        _errorMessage = 'Oops! There was an error. Please try again later.';
        _isLoading = false;
      });
    }
  }

  Future<void> _getUserRole() async {
    try {
      final userInfo = await AuthService.getUserInfo();
      if (userInfo != null && userInfo.containsKey('role')) {
        setState(() {
          _userRole = userInfo['role'];
        });
      }
    } catch (e) {
      print('Error fetching user role: $e');
    }
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

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open: $url')),
      );
    }
  }

  void _showAddNoteDialog() {
    _noteController.clear();
    _isSubmittingNote = false;

    showDialog(
      context: context,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Add Service Note'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _noteController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Enter your note here...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_isSubmittingNote)
                      const Padding(
                        padding: EdgeInsets.only(top: 16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: _isSubmittingNote
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: _isSubmittingNote
                        ? null
                        : () async {
                      if (_noteController.text
                          .trim()
                          .isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a note')),
                        );
                        return;
                      }

                      setState(() {
                        _isSubmittingNote = true;
                      });

                      final success = await _submitServiceNote(
                          _noteController.text);

                      if (success && context.mounted) {
                        Navigator.pop(context);
                        _fetchServiceRequestDetails(); // Refresh the data
                      } else if (context.mounted) {
                        setState(() {
                          _isSubmittingNote = false;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF388E3C),
                    ),
                    child: const Text(
                      'Add Note',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<bool> _submitServiceNote(String noteText) async {
    try {
      final token = await AuthService.getAuthToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication token missing')),
        );
        return false;
      }

      final baseUrl = Config.backendUrl;
      final apiUrl = '$baseUrl/service_request/${widget
          .serviceRequestId}/notes/create/';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'note': noteText,
          'service_request': widget.serviceRequestId
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note added successfully')),
        );
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to add note: ${response.reasonPhrase}')),
        );
        return false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      return false;
    }
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        // User canceled the picker
        return;
      }

      final file = result.files.first;

      if (file.path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to access the selected file')),
        );
        return;
      }

      setState(() {
        _isUploadingAttachment = true;
      });

      final success = await _uploadAttachment(File(file.path!), file.name);

      if (success) {
        // Refresh the service request details to show the new attachment
        _fetchServiceRequestDetails();
      }

      setState(() {
        _isUploadingAttachment = false;
      });
    } catch (e) {
      setState(() {
        _isUploadingAttachment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting file: $e')),
      );
    }
  }

  Future<bool> _uploadAttachment(File file, String fileName) async {
    try {
      final token = await AuthService.getAuthToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication token missing')),
        );
        return false;
      }

      final baseUrl = Config.backendUrl;
      final apiUrl = '$baseUrl/service_request/${widget.serviceRequestId}/upload/';

      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Determine content type based on file extension
      final extension = path.extension(fileName).toLowerCase();
      String contentType;

      if (extension == '.pdf') {
        contentType = 'application/pdf';
      } else if (extension == '.jpg' || extension == '.jpeg') {
        contentType = 'image/jpeg';
      } else if (extension == '.png') {
        contentType = 'image/png';
      } else if (extension == '.doc' || extension == '.docx') {
        contentType = 'application/msword';
      } else {
        contentType = 'application/octet-stream';
      }

      final fileStream = http.ByteStream(file.openRead());
      final fileLength = await file.length();
      final multipartFile = http.MultipartFile(
        'files',
        fileStream,
        fileLength,
        filename: fileName,
        contentType: MediaType.parse(contentType),
      );

      // Add service request ID
      request.fields['service_request'] = widget.serviceRequestId;
      
      request.files.add(multipartFile);

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attachment uploaded successfully')),
        );
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload attachment: ${response.reasonPhrase} (${response.statusCode})')),
        );
        return false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading attachment: $e')),
      );
      return false;
    }
  }

  Future<void> _downloadFile(String attachmentId, String fileName) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    final client = http.Client();
    
    try {
      // Request storage permission
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (status.isDenied) {
          throw Exception('Storage permission is required to download files');
        }
      }
      
      // Get auth token
      final token = await AuthService.getAuthToken();
      if (token == null) {
        throw Exception('Authentication token missing');
      }
      
      // Create temporary file path
      final tempDir = await getTemporaryDirectory();
      final tempFilePath = '${tempDir.path}/$fileName';
      final file = File(tempFilePath);
      
      // Use dedicated download endpoint instead of direct file URL
      final baseUrl = Config.backendUrl;
      final downloadUrl = '$baseUrl/service_request/${widget.serviceRequestId}/attachments/$attachmentId/download/';
      
      // Prepare the HTTP client with auth header
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['Authorization'] = 'Bearer $token';
      
      // Get response stream
      final response = await client.send(request);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download file: ${response.reasonPhrase}');
      }
      
      // Get total file size
      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      
      // Open file for writing
      final fileStream = file.openWrite();
      
      // Download with progress
      await response.stream.forEach((chunk) {
        fileStream.add(chunk);
        receivedBytes += chunk.length;
        
        if (totalBytes > 0) {
          final progress = receivedBytes / totalBytes;
          setState(() {
            _downloadProgress = progress;
          });
        }
      });
      
      // Close the file
      await fileStream.flush();
      await fileStream.close();
      
      // Save the file to device storage
      if (Platform.isAndroid) {
        final params = SaveFileDialogParams(
          sourceFilePath: tempFilePath,
          fileName: fileName,
        );
        final filePath = await FlutterFileDialog.saveFile(params: params);
        
        if (filePath == null) {
          throw Exception('File save canceled');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File saved to: $filePath')),
        );
      } else if (Platform.isIOS) {
        // For iOS, we'll use share_plus package
        // This will open the share sheet so the user can decide where to save the file
        await Share.shareXFiles(
          [XFile(tempFilePath)],
          text: 'Sharing $fileName',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading file: $e')),
      );
    } finally {
      setState(() {
        _isDownloading = false;
      });
      
      // Close any remaining streams
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = _serviceRequestDetails;
    final status = details?['status'] ?? 'Unknown';

    Map<String, dynamic>? address;
    if (details != null && details['address'] is Map) {
      address = details['address'] as Map<String, dynamic>;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Request #${widget.serviceRequestId}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF388E3C),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchServiceRequestDetails,
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
        child: _isLoading && details == null
            ? const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF388E3C)),
          ),
        )
            : _errorMessage != null && details == null
            ? Center(
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
                onPressed: _fetchServiceRequestDetails,
                child: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF388E3C),
                ),
              ),
            ],
          ),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and status section
                      Text(
                        details?['title'] ?? 'Service Request',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Created: ${_formatDateTime(details?['created_at']
                            ?.toString())}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),

                      // Only show action buttons if not cancelled or completed
                      if (!['cancelled', 'completed'].contains(status.toLowerCase()))
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),

                            // Make Payment Button (for customers with pending payment)
                            if (!_isEditing &&
                                _userRole == 'Customer' &&
                                status.toLowerCase() == 'pending payment')
                              ElevatedButton.icon(
                                onPressed: () => _navigateToPayment(),
                                icon: const Icon(Icons.payment, color: Colors.white),
                                label: const Text(
                                  'Make Payment',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),

                            // Add space between buttons when showing both
                            if (!_isEditing &&
                                _userRole == 'Customer' &&
                                status.toLowerCase() == 'pending payment')
                              const SizedBox(height: 8),

                            // Edit Request Button - show for all non-cancelled/completed requests
                            if (!_isEditing && _userRole != null)
                              ElevatedButton.icon(
                                onPressed: _prepareForEditing,
                                icon: const Icon(Icons.edit, color: Colors.white),
                                label: const Text(
                                  'Edit Request',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF388E3C),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),

                            // Cancel Request Button - only show for customers when status is not pending payment
                            if (!_isEditing &&
                                _userRole == 'Customer' &&
                                status.toLowerCase() != 'pending payment')
                              Column(
                                children: [
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: _showCancelRequestDialog,
                                    icon: const Icon(Icons.cancel, color: Colors.white),
                                    label: const Text(
                                      'Cancel Request',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      // Make it same as Edit Request button
                                      minimumSize: const Size(double.infinity, 0),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),

                      // Add edit form fields if in editing mode
                      if (_isEditing && _userRole == 'Technician') ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Update Status',
                            border: OutlineInputBorder(),
                          ),
                          value: _selectedStatus,
                          items: [
                            'New',
                            'Assigned',
                            'In Progress',
                            'Completed',
                            'Cancelled',
                            'Pending Payment',
                          ].map((status) =>
                              DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              )).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedStatus = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Add amount field
                        TextFormField(
                          controller: _amountController,
                          decoration: const InputDecoration(
                            labelText: 'Amount (\$)',
                            hintText: '0.00',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: TextInputType.numberWithOptions(
                              decimal: true),
                          // Optional validation
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isEditing = false;
                                });
                              },
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _saveUpdates,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF388E3C),
                              ),
                                child: const Text(
                                'Save Changes',
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Main Details Card
              _isEditing && _userRole == 'Customer'
                  ? Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edit Request Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 12),

                      // Request Type
                      const Text(
                        'Request Type:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF388E3C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        value: _selectedRequestType,
                        items: [
                          'General',
                          'Technical',
                        ].map((type) =>
                            DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            )).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRequestType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      const Text(
                        'Description:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF388E3C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Enter description',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Scheduled Date and Time
                      const Text(
                        'Schedule:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF388E3C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Date picker
                          Expanded(
                            child: TextFormField(
                              controller: _scheduledDateController,
                              decoration: const InputDecoration(
                                hintText: 'YYYY-MM-DD',
                                labelText: 'Date',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              onTap: () async {
                                // Hide keyboard
                                FocusScope.of(context).requestFocus(
                                    FocusNode());

                                // Show date picker
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(
                                      const Duration(days: 1)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                      const Duration(days: 90)),
                                );

                                if (picked != null) {
                                  final formattedDate = "${picked.year}-${picked
                                      .month.toString().padLeft(
                                      2, '0')}-${picked.day.toString().padLeft(
                                      2, '0')}";
                                  setState(() {
                                    _scheduledDateController.text =
                                        formattedDate;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Time picker
                          Expanded(
                            child: TextFormField(
                              controller: _scheduledTimeController,
                              decoration: const InputDecoration(
                                hintText: 'HH:MM',
                                labelText: 'Time',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.access_time),
                              ),
                              onTap: () async {
                                // Hide keyboard
                                FocusScope.of(context).requestFocus(
                                    FocusNode());

                                // Show time picker
                                final TimeOfDay? picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );

                                if (picked != null) {
                                  final formattedTime = "${picked.hour
                                      .toString().padLeft(2, '0')}:${picked
                                      .minute.toString().padLeft(2, '0')}";
                                  setState(() {
                                    _scheduledTimeController.text =
                                        formattedTime;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isEditing = false;
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _saveUpdates,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF388E3C),
                            ),
                            child: const Text(
                                'Save Changes',
                                style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
                  : Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Request Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const Divider(),
                      _buildInfoRow(
                          'Request Type', details?['request_type'] ?? 'N/A'),
                      _buildInfoRow('Description',
                          details?['description'] ?? 'No description provided'),

                      // Add amount field with proper formatting
                      if (details?['amount'] != null)
                        _buildInfoRow(
                            'Amount',
                            '\$${(details?['amount'] is num
                                ? (details?['amount'] as num).toStringAsFixed(2)
                                : details?['amount'] ?? '0.00')}'
                        ),

                      if (address != null)
                        _buildInfoRow(
                            'Service Address',
                            '${address['address'] ?? ''}, ${address['city'] ??
                                ''}, ${address['state'] ??
                                ''}, ${address['zipcode'] ?? ''}'
                        ),
                      if (details?['scheduled_date'] != null)
                        _buildInfoRow(
                            'Scheduled At',
                            _formatDateTime(
                                '${details?['scheduled_date']} ${details?['scheduled_time']}')
                        ),
                      if (details?['assigned_to'] != null)
                        _buildInfoRow('Assigned To',
                            details?['assigned_to'] ?? 'Not assigned'),
                      _buildInfoRow(
                          'Last Updated', _formatDateTime(details?['updated_at']
                          ?.toString())),
                    ],
                  ),
                ),
              ),

              // Service Notes Card
              Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with improved layout
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Service Notes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Only show add note button if the request is not cancelled or completed
                          if (!['cancelled', 'completed'].contains(
                              status.toLowerCase()))
                            _isLoading
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF388E3C)),
                              ),
                            )
                                : IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: _showAddNoteDialog,
                              tooltip: 'Add Note',
                              color: const Color(0xFF388E3C),
                            ),
                        ],
                      ),
                      const Divider(),

                      // Empty state with proper constraints
                      if (_serviceNotes.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Column(
                              children: [
                                const Text('No service notes available'),
                                const SizedBox(height: 16),
                                // Only show add note button if the request is not cancelled or completed
                                if (!['cancelled', 'completed'].contains(
                                    status.toLowerCase()))
                                  ElevatedButton.icon(
                                    onPressed: _showAddNoteDialog,
                                    icon: const Icon(Icons.add, color: Colors.white),
                                    label: const Text(
                                      'Add First Note',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF388E3C),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )
                      // Notes list with proper constraints
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _serviceNotes.length,
                          itemBuilder: (context, index) {
                            final note = _serviceNotes[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              color: Colors.grey[50],
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Author and date with proper constraints
                                    Row(
                                      children: [
                                        // Author with flex and overflow handling
                                        Expanded(
                                          child: Text(
                                            note['created_by'] ?? 'System',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // Date with minimum width
                                        Text(
                                          _formatDateTime(
                                              note['created_at']?.toString()),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Note content with proper text wrapping
                                    Text(
                                      note['note'] ?? '',
                                      style: const TextStyle(fontSize: 14),
                                      // Allow text to wrap naturally
                                      softWrap: true,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                    ],
                  ),
                ),
              ),

              // Attachments Card
              Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with improved layout and + icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Attachments',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                          // Only show attach button if not cancelled or completed
                          if (!['cancelled', 'completed'].contains(status.toLowerCase()))
                            _isUploadingAttachment
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF388E3C)),
                              ),
                            )
                                : IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: _pickAndUploadFile,
                              tooltip: 'Add Attachment',
                              color: const Color(0xFF388E3C),
                            ),
                        ],
                      ),
                      const Divider(),

                      // Empty state with proper constraints
                      if (_attachments.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.attach_file,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'No attachments available',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                // Only show add attachment button if not cancelled or completed
                                if (!['cancelled', 'completed'].contains(status.toLowerCase()))
                                  TextButton.icon(
                                    onPressed: _isUploadingAttachment ? null : _pickAndUploadFile,
                                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFF388E3C)),
                                    label: const Text(
                                      'Add First Attachment',
                                      style: TextStyle(color: Color(0xFF388E3C)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )
                      // Attachments list with proper constraints
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _attachments.length,
                          itemBuilder: (context, index) {
                            final attachment = _attachments[index];
                            final fileName = attachment['filename'] ??
                                attachment['filename'] ??
                                'Attachment ${index + 1}';
                            final fileUrl = attachment['file_url'] ??
                                attachment['url'];

                            IconData iconData = Icons.insert_drive_file;
                            if (fileName.toLowerCase().endsWith('.pdf')) {
                              iconData = Icons.picture_as_pdf;
                            } else
                            if (fileName.toLowerCase().endsWith('.jpg') ||
                                fileName.toLowerCase().endsWith('.jpeg') ||
                                fileName.toLowerCase().endsWith('.png')) {
                              iconData = Icons.image;
                            } else
                            if (fileName.toLowerCase().endsWith('.doc') ||
                                fileName.toLowerCase().endsWith('.docx')) {
                              iconData = Icons.description;
                            }

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 4.0
                              ),
                              leading: Icon(iconData, color: const Color(0xFF388E3C)),
                              title: Text(
                                fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Uploaded by ${attachment['uploaded_by']} on: ${_formatDateTime(
                                        attachment['created_at']?.toString() ??
                                            '')} * Size: ${_formatFileSize(attachment['size'])}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  
                                  // Show download progress if this file is being downloaded
                                  if (_isDownloading && _currentDownloadName == fileName)
                                    LinearProgressIndicator(
                                      value: _downloadProgress,
                                      backgroundColor: Colors.grey[300],
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF388E3C)),
                                    ),
                                ],
                              ),
                              trailing: _isDownloading && _currentDownloadName == fileName
                                ? const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF388E3C)),
                                    strokeWidth: 2,
                                  )
                                : const Icon(Icons.download, size: 20),
                              onTap: () {
                                if (_isDownloading) {
                                  // Don't allow multiple simultaneous downloads
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('A download is already in progress')),
                                  );
                                  return;
                                }
                                
                                final attachmentId = attachment['id']?.toString();
                                if (attachmentId != null) {
                                  setState(() => _currentDownloadName = fileName);
                                  _downloadFile(attachmentId, fileName);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Attachment ID not available')),
                                  );
                                }
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF388E3C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _prepareForEditing() {
    if (_serviceRequestDetails == null) return;

    // Don't allow editing if the status is Cancelled or Completed
    final status = _serviceRequestDetails!['status'];
    if (status != null) {
      if (['cancelled', 'completed'].contains(status.toLowerCase())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Cancelled or completed requests cannot be edited')),
        );
        return;
      }
    }

    _descriptionController.text = _serviceRequestDetails!['description'] ?? '';
    _scheduledDateController.text =
        _serviceRequestDetails!['scheduled_date'] ?? '';
    _scheduledTimeController.text =
        _serviceRequestDetails!['scheduled_time'] ?? '';
    _selectedRequestType = _serviceRequestDetails!['request_type'];
    _amountController.text =
        _serviceRequestDetails!['amount']?.toString() ?? '';

    if (_serviceRequestDetails!['address'] != null &&
        _serviceRequestDetails!['address'] is Map) {
      Map<String, dynamic> address = _serviceRequestDetails!['address'];
      _selectedAddress = address['id']?.toString();
    }

    _selectedStatus = _serviceRequestDetails!['status'];

    setState(() {
      _isEditing = true;
    });
  }

  Future<void> _saveUpdates() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await AuthService.getAuthToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication token missing')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final baseUrl = Config.backendUrl;
      final apiUrl = '$baseUrl/service_request/${widget.serviceRequestId}/edit/';

      Map<String, dynamic> updateData = {};

      // Only add fields that the user is allowed to edit based on role
      if (_userRole == 'Customer') {
        // For cancellations, only update the status
        if (_selectedStatus == 'Cancelled') {
          updateData['status'] = _selectedStatus;
        } else {
          // Normal edit operation
          if (_selectedRequestType != null) {
            updateData['request_type'] = _selectedRequestType;
          }
          if (_descriptionController.text.isNotEmpty) {
            updateData['description'] = _descriptionController.text;
          }
          if (_selectedAddress != null) {
            updateData['address_id'] = _selectedAddress;
          }
          if (_scheduledDateController.text.isNotEmpty) {
            updateData['scheduled_date'] = _scheduledDateController.text;
          }
          if (_scheduledTimeController.text.isNotEmpty) {
            updateData['scheduled_time'] = _scheduledTimeController.text;
          }
        }
      } else if (_userRole == 'Technician' || _userRole == 'Admin') {
        if (_selectedStatus != null) {
          updateData['status'] = _selectedStatus;
        }

        // Add amount field for Technician
        if (_amountController.text.isNotEmpty) {
          // Convert to double and handle potential formatting issues
          try {
            final amount = double.parse(_amountController.text);
            updateData['amount'] = amount;
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid amount format')),
            );
          }
        }
      }

      final response = await http.patch(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          _selectedStatus == 'Cancelled'
              ? const SnackBar(content: Text('Service request cancelled successfully'))
              : const SnackBar(content: Text('Service request updated successfully')),
        );

        // Refresh data
        await _fetchServiceRequestDetails();

        setState(() {
          _isEditing = false;
        });

        // Return true to the calling screen to trigger a refresh
        Navigator.of(context).pop(true);
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              'Failed to update service request: ${response.reasonPhrase}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating service request: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showCancelRequestDialog() {
    if (_serviceRequestDetails == null) return;

    // Don't allow cancellation if the status is already Cancelled or Completed
    final status = _serviceRequestDetails!['status'];
    if (status != null &&
        ['cancelled', 'completed'].contains(status.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This request has already been cancelled or completed')),
      );
      return;
    }

    _noteController.clear(); // Reuse the note controller for the cancellation reason

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Cancel Service Request'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to cancel this service request?',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                const Text('Please provide a reason for cancellation:'),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Enter cancellation reason...',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_isSubmittingCancel) // Added flag for cancel operation
                  const Padding(
                    padding: EdgeInsets.only(top: 16.0),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text(
                            'Processing cancellation...',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          )
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _isSubmittingCancel ? null : () => Navigator.pop(dialogContext),
                child: const Text('Back'),
              ),
              ElevatedButton(
                onPressed: _isSubmittingCancel
                    ? null
                    : () async {
                      if (_noteController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please provide a reason for cancellation')),
                        );
                        return;
                      }

                      // Update the dialog UI to show loading state
                      setDialogState(() {
                        _isSubmittingCancel = true;
                      });
                      
                      // Also update the parent state to reflect changes in case dialog is dismissed
                      setState(() {
                        _isSubmittingCancel = true;
                      });

                      try {
                        // Set status to cancelled
                        _selectedStatus = 'Cancelled';

                        // Save the update to change status
                        await _saveUpdates();

                        // Add the cancellation reason as a note
                        await _submitServiceNote("Cancellation reason: ${_noteController.text}");

                        // Update success message
                        if (context.mounted) { 
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Service request cancelled successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        // Show error if something went wrong
                        if (context.mounted) {
                          print ('Error cancelling request: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Oops! There was an error. Please try again later.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        // Reset the submitting state
                        setState(() {
                          _isSubmittingCancel = false;
                        });
                        
                        // Close the dialog if it's still open
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      }
                    },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text(
                  'Cancel Request',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _navigateToPayment() {
    // Get the amount from the service request
    final amount = _serviceRequestDetails?['amount'];

    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No payment amount specified')),
      );
      return;
    }

    // Convert the amount to a double regardless of its original type
    double paymentAmount;

    if (amount is double) {
      paymentAmount = amount;
    } else if (amount is int) {
      paymentAmount = amount.toDouble();
    } else if (amount is String) {
      try {
        paymentAmount = double.parse(amount);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid payment amount format')),
        );
        return;
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unsupported payment amount type')),
      );
      return;
    }

    // Navigate to the payment screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PaymentScreen(
              planId: widget.serviceRequestId,
              planName: 'Service Request #${widget.serviceRequestId}',
              purpose: 'Service Request #${widget.serviceRequestId}',
              amount: paymentAmount,
              isYearlyBilling: false,
              from_object: 'service_request',
            ),
      ),
    ).then((result) {
      // Handle the result when returning from payment screen
      if (result == true) {
        // Payment was successful, refresh the service request details
        _fetchServiceRequestDetails();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Payment successful! Your service request has been updated.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Also notify the parent screen to refresh
        Navigator.of(context).pop(true);
      }
    });
  }
}

String _formatFileSize(dynamic size) {
  // Handle null values
  if (size == null) return 'Unknown size';
  
  // Convert to bytes
  double bytes;
  if (size is int) {
    bytes = size.toDouble();
  } else if (size is double) {
    bytes = size;
  } else if (size is String) {
    try {
      bytes = double.parse(size);
    } catch (e) {
      return size.toString();
    }
  } else {
    return 'Unknown size';
  }
  
  // Format based on size
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  int i = 0;
  
  while (bytes >= 1024 && i < suffixes.length - 1) {
    bytes /= 1024;
    i++;
  }
  
  // Format with appropriate decimal places
  if (i == 0) {
    // For bytes, no decimal places
    return '${bytes.round()} ${suffixes[i]}';
  } else if (bytes >= 100) {
    // For larger numbers, no decimal places
    return '${bytes.round()} ${suffixes[i]}';
  } else if (bytes >= 10) {
    // For medium numbers, one decimal place
    return '${bytes.toStringAsFixed(1)} ${suffixes[i]}';
  } else {
    // For small numbers, two decimal places
    return '${bytes.toStringAsFixed(2)} ${suffixes[i]}';
  }
}
