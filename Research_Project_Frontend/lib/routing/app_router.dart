import 'package:flutter/material.dart';

import '../screens/home_screen.dart';

/// Central App Router
class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    return MaterialPageRoute(builder: (_) => const HomeScreen());
  }
}
