import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
      ),
      body: Center(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.purpleMid,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.settings_outlined, size: 64, color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Próximamente',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
