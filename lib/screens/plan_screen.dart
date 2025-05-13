import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:flutter_stripe/flutter_stripe.dart' as stripe;

import 'package:ppal/services/auth_service.dart';
import 'package:ppal/common.dart';
import 'package:ppal/screens/payment_screen.dart';
import 'package:ppal/screens/login_screen.dart'; // Import LoginScreen


class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _userRole;
  String? _currentPlanId;
  bool _isYearlyBilling = true;
  final double _yearlyDiscountPercent = double.tryParse(Config.yearlyPlanDiscount.toString()) ?? 0.0;
  final double _monthlyPriceProfessional = double.tryParse(Config.monthlyPriceProfessional.toString()) ?? 0.0;

  // Track subscription status
  bool _hasSubscription = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final token = await AuthService.getAuthToken();
      
      // If token is null, user is not logged in - show plan info without requiring login
      if (token == null) {
        setState(() {
          _userRole = null;
          _hasSubscription = false;
          _currentPlanId = null;
          _isLoading = false;
        });
        return; // This return is important - don't try to make API calls without a token
      }

      // The rest of the function only executes if user is logged in
      // Get user info from AuthService instead of a separate API call
      final userInfo = await AuthService.getUserInfo();
      if (userInfo == null) {
        setState(() {
          _userRole = null;
          _hasSubscription = false;
          _currentPlanId = null;
          _isLoading = false;
        });
        return;
      }

      final baseUrl = Config.backendUrl;
        
      // Now check for subscription status
      final planResponse = await http.get(
        Uri.parse('$baseUrl/common/plans/'),
        headers: {'Authorization': 'Bearer $token'},
      );
        
      if (planResponse.statusCode == 200) {
        final res = json.decode(planResponse.body);
        final planData = res['results'];
        
        // Check if the API returned any subscription data
        if (planData != null && planData.isNotEmpty) {
          // User has a subscription
          final subscription = planData[0]; // Get the first (and only) record
          final planType = subscription['plan_type'];
          
          // Determine the plan ID based on the plan type
          String? planId;
          if (planType == 'Basic') {
            planId = '1';
          } else if (planType == 'Professional') {
            planId = '2';
          } else if (planType == 'Enterprise') {
            planId = '3';
          }
          
          setState(() {
            _userRole = userInfo['role'];
            _hasSubscription = true;
            _currentPlanId = planId;
            // If billing cycle is included in the API response:
            // _isYearlyBilling = subscription['billing_cycle'] == 'yearly';
            _isLoading = false;
          });
        } else {
          // No subscription found
          setState(() {
            _userRole = userInfo['role'];
            _hasSubscription = false;
            _currentPlanId = null;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _userRole = userInfo['role'];
          _hasSubscription = false;
          _currentPlanId = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Even if there's an error, still show plans to non-logged-in users
      setState(() {
        _userRole = null;
        _hasSubscription = false;
        _currentPlanId = null;
        _isLoading = false;
        _errorMessage = null; // Don't show error messages for non-logged in users
      });
    }
  }

  Future<void> _subscribeToPlan(String planId) async {
    try {
      // Check if user is logged in
      final token = await AuthService.getAuthToken();
      if (token == null) {
        // Show login dialog
        _showLoginRequiredDialog(() {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          ).then((_) {
            // After login (if successful), try to subscribe again
            _loadUserInfo().then((_) {
              _subscribeToPlan(planId);
            });
          });
        });
        return;
      }

      setState(() {
        _isLoading = true;
      });

      // Handle free plan differently than paid plans
      if (planId == '1') {  // Basic Plan is free
        // Call plan enrollment API directly for free plans
        final baseUrl = Config.backendUrl;
        final response = await http.post(
          Uri.parse('$baseUrl/common/plans/enroll/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'plan_type': 'Basic',
            'duration': _isYearlyBilling ? 'yearly' : 'monthly',
            'amount': 0.0,
            'payment_status': 'pending'  // It's free, so payment status is irrelevant
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully enrolled in Basic plan!')),
          );
          
          // Update the UI
          setState(() {
            _hasSubscription = true;
            _currentPlanId = planId;
          });
          
          // Refresh subscription data
          _loadUserInfo();
        } else {
          final responseData = json.decode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message'] ?? 'Failed to enroll in Basic plan')),
          );
        }
      } else {
        // For paid plans
        final planName = planId == '2' ? 'Professional' : 'Enterprise';
        
        // For Enterprise plan, show contact sales dialog
        if (planId == '3') {
          _contactSales();
          setState(() {
            _isLoading = false;
          });
          return;
        }
        
        // For Professional plan (planId == '2'), calculate correct amount based on billing cycle
        double amount = _monthlyPriceProfessional; // Monthly price for Professional plan
        
        // Apply yearly discount if yearly billing is selected
        if (_isYearlyBilling) {
          // Calculate yearly price with discount
          amount = _calculateYearlyPrice(amount);
        }
        
        setState(() {
          _isLoading = false;
        });
        
        // Navigate to payment screen
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentScreen(
              planId: planId,
              planName: planName,
              purpose: 'Subscription for $planName plan',
              amount: amount,
              isYearlyBilling: _isYearlyBilling,
              from_object: 'plan',
            ),
          ),
        );
        
        // Check if payment was successful
        if (result == true) {
          // If payment was successful, refresh the UI
          setState(() {
            _hasSubscription = true;
            _currentPlanId = planId;
          });
          
          // Refresh subscription data
          _loadUserInfo();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _subscribeToProfessionalPlan(bool isYearly) async {
    try {
      // Check if user is logged in
      final token = await AuthService.getAuthToken();
      if (token == null) {
        // Show login dialog
        _showLoginRequiredDialog(() {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          ).then((_) {
            // After login (if successful), try to subscribe again
            _loadUserInfo().then((_) {
              _subscribeToProfessionalPlan(isYearly);
            });
          });
        });
        return;
      }

      setState(() {
        _isLoading = true;
      });
    
      // Calculate amount based on selected billing cycle
      double amount = _monthlyPriceProfessional; // Monthly price
    
      // Apply yearly discount if yearly billing is selected
      if (isYearly) {
        amount = _calculateYearlyPrice(amount);
      }
      
      setState(() {
        _isLoading = false;
      });
      
      // Navigate to payment screen with proper billing cycle
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            planId: '2', // Professional plan
            planName: 'Professional',
            purpose: 'Subscription for Professional plan',
            amount: amount,
            isYearlyBilling: isYearly,
            from_object: 'plan',
          ),
        ),
      );
    
      // Check if payment was successful
      if (result == true) {
        // If payment was successful, refresh the UI
        setState(() {
          _hasSubscription = true;
          _currentPlanId = '2';
        });
        
        // Refresh subscription data
        _loadUserInfo();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // For Enterprise plan - contact sales
  void _contactSales() async {
    // Check if user is logged in
    final token = await AuthService.getAuthToken();
    if (token == null) {
      // Show login dialog
      _showLoginRequiredDialog(() {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        ).then((_) {
          // After login (if successful), show contact dialog
          _loadUserInfo().then((_) {
            _showContactSalesDialog();
          });
        });
      });
      return;
    }

    _showContactSalesDialog();
  }

  // Add a helper method to show login required dialog
  void _showLoginRequiredDialog(VoidCallback onLogin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.login,
              size: 48,
              color: Color(0xFF388E3C),
            ),
            SizedBox(height: 16),
            Text(
              'You need to log in or create an account to subscribe to a plan.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onLogin();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF388E3C),
            ),
            child: const Text(
              'Login',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Calculate yearly price with discount
  double _calculateYearlyPrice(double monthlyPrice) {
    final yearlyPrice = monthlyPrice * 12;
    final discountAmount = yearlyPrice * (_yearlyDiscountPercent / 100);
    return yearlyPrice - discountAmount;
  }

  // Format price based on billing cycle
  String _formatPrice(dynamic price, {bool yearly = false}) {
    if (price == null || price == 'Free' || price == 'Custom') {
      return price.toString();
    }
    
    try {
      if (price is String && price.startsWith('\$')) {
        price = double.parse(price.substring(1));
      } else if (price is String) {
        price = double.parse(price);
      }
      
      if (yearly) {
        price = _calculateYearlyPrice(price);
      }
      
      return '\$${price.toStringAsFixed(2)}';
    } catch (e) {
      return price.toString();
    }
  }

  // Add this method to _PlanScreenState class
  void _showContactSalesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enterprise Plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.business,
              size: 48,
              color: Color(0xFF388E3C),
            ),
            const SizedBox(height: 16),
            const Text(
              'Thank you for your interest in our Enterprise plan!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Our Enterprise plan is custom-tailored to fit your business needs. Please contact our sales team for personalized pricing and features.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Contact Information:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.email, size: 16, color: Color(0xFF388E3C)),
                const SizedBox(width: 8),
                SelectableText(
                  'enterprise@pumperpal.com',
                  style: const TextStyle(
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Color(0xFF388E3C)),
                const SizedBox(width: 8),
                SelectableText(
                  '(800) 555-1234',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'A sales representative will contact you within 1 business day.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // Attempt to launch email client
              final Uri emailLaunchUri = Uri(
                scheme: 'mailto',
                path: 'enterprise@pumperpal.com',
                query: 'subject=Enterprise Plan Inquiry',
              );
              launchUrl(emailLaunchUri);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF388E3C),
            ),
            child: const Text(
              'Send Email',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Maintenance Plans',
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
            : _buildPlansView(),
      ),
    );
  }

  Widget _buildPlansView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show subscription status message
          if (_hasSubscription) 
            Card(
              elevation: 2,
              color: const Color(0xFFE8F5E9),
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: IntrinsicHeight( // Add this wrapper
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start, // Align to top
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF388E3C),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min, // Add this
                          children: [
                            const Text(
                              'You have an active subscription!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your current plan is highlighted below. You can upgrade or change plans anytime.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const Text(
            'Choose a Maintenance Plan',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Regular maintenance helps extend the life of your septic system and prevents costly repairs.',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 24),
          
          // Pro plan billing cycle toggle - only show if not on Free plan
          if (_currentPlanId != '1') 
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pro Plan Billing:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Monthly option
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isYearlyBilling = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              decoration: BoxDecoration(
                                color: !_isYearlyBilling ? const Color(0xFFE8F5E9) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: !_isYearlyBilling ? const Color(0xFF388E3C) : Colors.grey.shade300,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Monthly',
                                  style: TextStyle(
                                    fontWeight: !_isYearlyBilling ? FontWeight.bold : FontWeight.normal,
                                    color: !_isYearlyBilling ? const Color(0xFF388E3C) : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Yearly option
                        Expanded(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isYearlyBilling = true;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: _isYearlyBilling ? const Color(0xFFE8F5E9) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _isYearlyBilling ? const Color(0xFF388E3C) : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Yearly',
                                      style: TextStyle(
                                        fontWeight: _isYearlyBilling ? FontWeight.bold : FontWeight.normal,
                                        color: _isYearlyBilling ? const Color(0xFF388E3C) : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_isYearlyBilling)
                                Positioned(
                                  top: -10,
                                  right: -10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF388E3C),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Save ${_yearlyDiscountPercent.toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        _isYearlyBilling 
                          ? 'Annual billing with ${_yearlyDiscountPercent.toStringAsFixed(0)}% discount' 
                          : 'Pay monthly with no commitment',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          
          // Basic Plan
          _buildPlanCard(
            title: 'Basic',
            price: 'Free',
            interval: '',
            features: [
              "Basic system monitoring",
              "Monthly maintenance reminders",
              "Email support",
              "Mobile app access"
            ],
            description: 'Essential monitoring for homeowners with standard septic systems.',
            isCurrentPlan: _currentPlanId == '1',
            onSubscribe: () => _subscribeToPlan('1'),
            planId: '1',
          ),
          const SizedBox(height: 16),
          
          // Professional Plan with both billing options
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: _currentPlanId == '2'
                  ? const BorderSide(color: Color(0xFF388E3C), width: 2)
                  : const BorderSide(color: Color(0xFF388E3C), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_currentPlanId != '2') // Show recommended badge if not current plan
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF388E3C),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'RECOMMENDED',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (_currentPlanId == '2') // Show current subscription badge if applicable
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF388E3C),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'CURRENT SUBSCRIPTION',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Plan header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded( // Add this wrapper
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Professional',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Enhanced coverage for homeowners who want extra protection.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      // Features section
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Features:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...[
                        "Advanced system monitoring",
                        "Real-time alerts",
                        "Priority support",
                        "Mobile app access",
                        "Smart cap integration",
                        "24/7 emergency support"
                      ].map(
                        (feature) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFF388E3C),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(feature)),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                      
                      // Billing options section - show both options directly in the card
                      const Text(
                        'Choose your billing cycle:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Monthly option
                      InkWell(
                        onTap: _currentPlanId == '2' ? null : () {
                          _subscribeToProfessionalPlan(false);
                        },
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Monthly',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Billed monthly',
                                      style: TextStyle(fontSize: 14, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                Text(
                                  _monthlyPriceProfessional.toStringAsFixed(2),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Yearly option with discount tag
                      InkWell(
                        onTap: _currentPlanId == '2' ? null : () {
                          _subscribeToProfessionalPlan(true);
                        },
                        child: Stack(
                          clipBehavior: Clip.none, // Fix overflow issues
                          children: [
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Annual',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Billed yearly',
                                          style: TextStyle(fontSize: 14, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '\$${_calculateYearlyPrice(_monthlyPriceProfessional).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2E7D32),
                                          ),
                                        ),
                                        Text(
                                          '(\$${(_monthlyPriceProfessional * 12).toStringAsFixed(2)})',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            decoration: TextDecoration.lineThrough,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF388E3C),
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(8),
                                    bottomLeft: Radius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'SAVE ${_yearlyDiscountPercent.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Enterprise Plan
          _buildPlanCard(
            title: 'Enterprise',
            price: 'Custom',
            interval: '',
            features: [
              "All Professional features",
              "Multiple system management",
              "Custom integrations",
              "Dedicated account manager",
              "API access",
              "Custom reporting"
            ],
            description: 'For businesses and property managers with multiple septic systems.',
            isCurrentPlan: _currentPlanId == '3',
            onSubscribe: _contactSales,
            planId: '3',
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String interval,
    required List<String> features,
    required String description,
    required bool isCurrentPlan,
    required VoidCallback onSubscribe,
    bool isPopular = false,
    required String planId,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentPlan
            ? const BorderSide(color: Color(0xFF388E3C), width: 2)
            : isPopular
                ? const BorderSide(color: Color(0xFF388E3C), width: 1)
                : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPopular && !isCurrentPlan)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF388E3C),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: const Text(
                'RECOMMENDED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (isCurrentPlan)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFF388E3C),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'CURRENT SUBSCRIPTION',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded( // Add this wrapper
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            softWrap: true,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          price == 'Custom' ? 'Custom' : 
                            price == 'Free' ? 'Free' :
                              _isYearlyBilling ? _formatPrice(price, yearly: true) : price,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        if (price != 'Free' && price != 'Custom')
                          Text(
                            'per ${_isYearlyBilling ? 'year' : interval}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        if (price == 'Custom')
                          Text(
                            'pricing',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                
                // Features section
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Features:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF388E3C),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature,
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Action button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isCurrentPlan ? null : onSubscribe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF388E3C),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: Text(
                      isCurrentPlan 
                          ? 'Current Subscription'
                          : planId == '3' 
                              ? 'Contact Sales' 
                              : _hasSubscription 
                                  ? 'Switch Plan' 
                                  : 'Subscribe',
                      style: TextStyle(
                        fontSize: 16,
                        color: isCurrentPlan ? Colors.grey[700] : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}