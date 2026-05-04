import 'package:flutter/material.dart';
import '../../../../core/widgets/bottom_nav_bar.dart';

class SmartLogisticsOptimizationScreen extends StatefulWidget {
  const SmartLogisticsOptimizationScreen({super.key});

  @override
  State<SmartLogisticsOptimizationScreen> createState() => _SmartLogisticsOptimizationScreenState();
}

class _SmartLogisticsOptimizationScreenState extends State<SmartLogisticsOptimizationScreen> {
  int _selectedNavIndex = 0;

  void _onNavItemTapped(int index) {
    if (index == 0) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _selectedNavIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Logistics Optimization'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const Center(
        child: Text('Smart Logistics Optimization module (IT22196460).'),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onItemTapped: _onNavItemTapped,
      ),
    );
  }
}
