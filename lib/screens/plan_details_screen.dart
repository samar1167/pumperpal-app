import 'package:flutter/material.dart';

class PlanDetailsScreen extends StatelessWidget {
  final Map<String, String> plan;

  const PlanDetailsScreen({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(plan['name'] ?? 'Plan Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan['name'] ?? 'No Name',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Details:",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF388E3C),
                  ),
                ),
                const SizedBox(height: 5),
                Text(plan['details'] ?? 'No Details'),
                const SizedBox(height: 15),
                const Text(
                  "Price:",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF388E3C),
                  ),
                ),
                const SizedBox(height: 5),
                Text(plan['price'] ?? 'No Price'),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      // Add subscription logic here
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Subscribed to ${plan['name']}!'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF388E3C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Subscribe'),
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
