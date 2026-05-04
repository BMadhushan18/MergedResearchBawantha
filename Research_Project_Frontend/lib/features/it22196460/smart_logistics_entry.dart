import 'package:flutter/material.dart';

import 'screens/home_screen.dart' as legacy;
import 'services/api_service.dart';
import 'services/hive_service.dart';

class SmartLogisticsLegacyFeature extends StatelessWidget {
  const SmartLogisticsLegacyFeature({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    final hiveService = HiveService();

    return legacy.HomeScreen(
      apiService: apiService,
      hiveService: hiveService,
    );
  }
}
