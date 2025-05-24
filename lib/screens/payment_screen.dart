import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ppal/common.dart';
import 'package:ppal/services/auth_service.dart';

class PaymentScreen extends StatefulWidget {
  final String planId;
  final String planName;
  final String purpose;
  final dynamic amount;
  final bool isYearlyBilling;
  final String from_object;

  const PaymentScreen({
    super.key,
    required this.planId,
    required this.planName,
    required this.purpose,
    required this.amount,
    required this.isYearlyBilling,
    required this.from_object,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isLoading = false;
  bool _stripeInitialized = false;
  bool _paymentCompleted = false;
  StreamSubscription? _paymentStatusSubscription;
  String? _currentPaymentIntentId;

  @override
  void initState() {
    super.initState();
    _initializeStripe();
  }

  @override
  void dispose() {
    _paymentStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeStripe() async {
    try {
      Stripe.publishableKey = Config.stripePublishableKey;
      Stripe.merchantIdentifier = 'merchant.com.your.app'; // TODO: For Apple Pay (iOS only)
      await Stripe.instance.applySettings();

      setState(() {
        _stripeInitialized = true;
      });
    } catch (e) {
      print('Stripe initialization error: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Oops! There was an error. Please try again later.')),
      );
    }
  }

  Future<void> _handlePayment() async {
    setState(() {
      _isLoading = true;
      _paymentCompleted = false;
    });

    try {
      // 1. Create payment intent
      final paymentIntent = await _createPaymentIntent((widget.amount).toInt(), 'USD');
      _currentPaymentIntentId = paymentIntent['payment_intent_id'];

      // 2. Initialize payment sheet (or card field)
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent['client_secret'],
          merchantDisplayName: 'Pumperpal',
        ),
      );

      // 3. Show payment sheet
      await Stripe.instance.presentPaymentSheet();

      // 4. Start polling for payment status
      _startPaymentStatusPolling(_currentPaymentIntentId!);

    } catch (e) {
      print('Payment error: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Oops! There was an error. Please try again later.')),
      );
    }
  }

  void _startPaymentStatusPolling(String paymentIntentId) {
    const pollingInterval = Duration(seconds: 2);
    const timeout = Duration(minutes: 5);
    final endTime = DateTime.now().add(timeout);

    _paymentStatusSubscription?.cancel();

    _paymentStatusSubscription = Stream.periodic(pollingInterval).asyncMap((_) {
      return _verifyPaymentStatus(paymentIntentId);
    }).takeWhile((_) => DateTime.now().isBefore(endTime)).listen((status) {
      if (status['status'] == 'succeeded') {
        _paymentStatusSubscription?.cancel();
        setState(() {
          _isLoading = false;
          _paymentCompleted = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment confirmed!')),
        );
      } else if (status['status'] == 'failed') {
        _paymentStatusSubscription?.cancel();
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed')),
        );
      }
      // Continue polling for other statuses
    }, onError: (e) {
      _paymentStatusSubscription?.cancel();
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error verifying payment: $e')),
      );
    });
  }

  Future<Map<String, dynamic>> _createPaymentIntent(int amount, String currency) async {
    final baseUrl = Config.backendUrl;
    final apiUrl = '$baseUrl/common/mobile/stripe/checkin/';
    
    // Get the auth token
    final userToken = await AuthService.getAuthToken();
    if (userToken == null) {
      throw Exception('User not authenticated');
    }

    // Get user info from AuthService instead of a separate API call
      final userInfo = await AuthService.getUserInfo();
      if (userInfo == null) {
        throw Exception('Failed to load user information.');
      }
    
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $userToken', // Add authentication header
      },
      body: json.encode({
        'obj_data': {
          'plan_type': widget.planName,
          'duration': widget.isYearlyBilling ? 'yearly' : 'monthly',
          'amount': amount,
          'payment_status': 'unpaid',
          if (widget.from_object == 'service_request') 'service_request_id': widget.planId, // needed for backend
        },
        'user_info': userInfo,
        'payment_for': widget.from_object, //critial: backend needs this to distinguish between plan and subscription
        'referrer': '/plan',
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create payment intent');
    }
  }

  Future<Map<String, dynamic>> _verifyPaymentStatus(String paymentIntentId) async {
    final baseUrl = Config.backendUrl;
    final apiUrl = '$baseUrl/common/mobile/stripe/confirm-payment/';
    
    // Get the auth token
    final userToken = await AuthService.getAuthToken();
    if (userToken == null) {
      throw Exception('User not authenticated');
    }
    
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $userToken', // Add authentication header
      },
      body: json.encode({
        'payment_intent_id': paymentIntentId,
      }),
    );

    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);
      // Simulate a successful payment status
      return {
      'status': 'succeeded',
      ...responseBody,
      };
    } else {
      throw Exception('Failed to verify payment status');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.green;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment Confirmation'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: themeColor.withOpacity(0.2), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Summary',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: themeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Divider(color: themeColor.withOpacity(0.3)),
                    SizedBox(height: 12),
                    _buildInfoRow('Purpose:', widget.purpose, themeColor: themeColor),
                    SizedBox(height: 8),
                    _buildInfoRow(
                      'Billing Cycle: ',
                      widget.isYearlyBilling ? 'Annual' : 'Monthly',
                      themeColor: themeColor,
                    ),
                    SizedBox(height: 8),
                    _buildInfoRow(
                      'Amount: ',
                      '\$${widget.amount.toStringAsFixed(2)}',
                      isHighlighted: true,
                      themeColor: themeColor,
                    ),
                    SizedBox(height: 16),
                    Divider(color: themeColor.withOpacity(0.3)),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Secure payment via',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(width: 8),
                        // Simple representation of Stripe logo
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFF635BFF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Stripe',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            if (_paymentCompleted)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 80),
                    SizedBox(height: 12),
                    Text(
                      'Payment Successful!',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: Icon(Icons.arrow_back),
                      label: Text('Take me Back'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        // Pop the current screen to return to the previous one
                        Navigator.of(context).pop(true); // Pass true to indicate successful payment
                      },
                    ),
                  ],
                ),
              ),
            Spacer(),
            // Only show terms text and payment button when payment is not completed
            if (!_paymentCompleted) ...[
              Text(
                'By proceeding with payment, you agree to our terms and conditions.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isLoading ? null : _handlePayment,
                child: _isLoading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Pay \$${widget.amount.toStringAsFixed(2)} Securely',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Update the helper method to use the green theme
  Widget _buildInfoRow(String label, String value, {bool isHighlighted = false, required Color themeColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            color: isHighlighted ? themeColor : Colors.black,
          ),
        ),
      ],
    );
  }
}