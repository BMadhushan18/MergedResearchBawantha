import 'package:flutter/material.dart';
import 'package:boq_frontend/features/it22172532/utils/constants.dart';

class MachineManagementScreen extends StatelessWidget {
  const MachineManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Logistics Management'),
        backgroundColor: AppColors.primary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.precision_manufacturing,
                size: 100, color: Colors.purple),
            SizedBox(height: 24),
            Text(
              'Smart Logistics',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            Text(
              'Management Module',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Track and manage construction machines, equipment, and hardware inventory',
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
