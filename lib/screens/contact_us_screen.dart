import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:ppal/common.dart';
import 'package:ppal/services/auth_service.dart';

class ContactUsScreen extends StatefulWidget {
  final String? prefilledSubject;
  
  const ContactUsScreen({Key? key, this.prefilledSubject}) : super(key: key);

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  
  bool _isSubmitting = false;
  bool _isLoggedIn = false;
  String? _submitError;
  bool _submitSuccess = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    
    // Pre-fill message if subject is provided
    if (widget.prefilledSubject != null && widget.prefilledSubject!.isNotEmpty) {
      _messageController.text = "Subject: ${widget.prefilledSubject}\n\n";
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final token = await AuthService.getAuthToken();
    if (token != null) {
      // Get user info to pre-fill the form
      final userInfo = await AuthService.getUserInfo();
      if (userInfo != null) {
        setState(() {
          _isLoggedIn = true;
          _nameController.text = userInfo['name'] ?? '';
          _emailController.text = userInfo['email'] ?? '';
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
        _submitError = null;
        _submitSuccess = false;
      });

      try {
        final baseUrl = Config.backendUrl;
        final apiUrl = '$baseUrl/common/contact/';
        
        // Get token if logged in
        String? authHeader;
        final token = await AuthService.getAuthToken();
        if (token != null) {
          authHeader = 'Bearer $token';
        }
        
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            if (authHeader != null) 'Authorization': authHeader,
          },
          body: jsonEncode({
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'mobile': _phoneController.text.trim(),
            'message': _messageController.text.trim(),
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          setState(() {
            _submitSuccess = true;
            // Clear form if successful
            if (!_isLoggedIn) {
              _nameController.clear();
              _emailController.clear();
            }
            _phoneController.clear();
            _messageController.clear();
          });
        } else {
          // Log the error but show a generic message
          print('Error submitting contact form: ${response.statusCode}, ${response.body}');
          setState(() {
            _submitError = 'Unable to submit your message. Please try again later.';
          });
        }
      } catch (e) {
        // Log the error but show a generic message
        print('Error submitting contact form: $e');
        setState(() {
          _submitError = 'Unable to connect to the server. Please check your internet connection.';
        });
      } finally {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us'),
        backgroundColor: const Color(0xFF388E3C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header section with background color
            Container(
              color: const Color(0xFF388E3C),
              padding: const EdgeInsets.all(24.0),
              width: double.infinity,
              child: Column(
                children: [
                  const Icon(
                    Icons.contact_support_outlined,
                    size: 60,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Get In Touch With Us',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We\'re here to help with any questions or concerns.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Form section
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Success message
                    if (_submitSuccess)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          border: Border.all(color: Colors.green.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Thank you for your message! We\'ll get back to you as soon as possible.',
                                style: TextStyle(color: Colors.green.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Error message
                    if (_submitError != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error, color: Colors.red.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _submitError!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Name field  
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                      enabled: !_isSubmitting,
                    ),
                    const SizedBox(height: 16),
                    
                    // Email field
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        // Basic email validation
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                      enabled: !_isSubmitting,
                    ),
                    const SizedBox(height: 16),
                    
                    // Phone field (optional)
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number (Optional)',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      // No validator needed since it's optional
                      enabled: !_isSubmitting,
                    ),
                    const SizedBox(height: 16),
                    
                    // Message field
                    TextFormField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.message),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your message';
                        }
                        if (value.trim().length < 10) {
                          return 'Your message should be at least 10 characters';
                        }
                        return null;
                      },
                      enabled: !_isSubmitting,
                    ),
                    const SizedBox(height: 24),
                    
                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF388E3C),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey,
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'SEND MESSAGE',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    
                    // Additional contact information
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    const Text(
                      'Other Ways to Reach Us',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Email
                    ListTile(
                      leading: const Icon(Icons.email_outlined, color: Color(0xFF388E3C)),
                      title: const Text('Email'),
                      subtitle: const Text('support@pumperpal.com'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    
                    // Phone
                    ListTile(
                      leading: const Icon(Icons.phone_outlined, color: Color(0xFF388E3C)),
                      title: const Text('Phone'),
                      subtitle: const Text('+1 (831) 776-8019'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    
                    // Address
                    ListTile(
                      leading: const Icon(Icons.location_on_outlined, color: Color(0xFF388E3C)),
                      title: const Text('Address'),
                      subtitle: const Text('325, North Main Street, Salinas, CA 93901'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}