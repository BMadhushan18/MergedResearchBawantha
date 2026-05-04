import 'package:flutter/material.dart';
import 'package:boq_frontend/features/it22172532/utils/constants.dart';

class CostEstimationScreen extends StatelessWidget {
  const CostEstimationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cost Estimation'),
        backgroundColor: AppColors.primary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.attach_money, size: 100, color: Colors.green),
            SizedBox(height: 24),
            Text(
              'Cost Estimation Module',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Comprehensive project cost estimation and budgeting',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ),
            SizedBox(height: 32),
            Text(
              'Coming Soon',
              style: TextStyle(fontSize: 18, color: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }
}
