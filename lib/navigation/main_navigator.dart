import 'package:flutter/material.dart';
import '../screens/config/config_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';

/// Nouveau Navigator pour gérer Config -> Dashboard
class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => MainNavigatorState();
}

class MainNavigatorState extends State<MainNavigator> {
  bool _showDashboard = false;

  void goToDashboard() {
    setState(() {
      _showDashboard = true;
    });
  }

  void goToConfig() {
    setState(() {
      _showDashboard = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showDashboard) {
      return DashboardScreen(
        onBackToConfig: goToConfig,
      );
    }
    return ConfigScreen(
      onConfigSaved: goToDashboard,
    );
  }
}