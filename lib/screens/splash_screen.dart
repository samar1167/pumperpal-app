import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ppal/screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    
    // Create animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    // Create a fade-in and slight scale animation
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    // Start the animation
    _animationController.forward();
    
    // Navigate to home screen after delay
    Timer(
      const Duration(seconds: 2), // Adjust timing as needed
      () => Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.8, end: 1.0).animate(_animation),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Replace with your actual logo
                Image.asset(
                  'assets/images/logo.jpg', // Make sure this path is correct
                  width: 200,
                  height: 200,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Welcome to PumperPal',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF388E3C),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}