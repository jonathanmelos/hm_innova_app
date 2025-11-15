import 'package:flutter/material.dart';
import 'home_page.dart';
import 'package:hm_innova_app/features/auth/presentation/technician_profile_page.dart';

/// App shell que monta tu UI original (cronómetro, botones, historial).
class HmInnovaApp extends StatelessWidget {
  const HmInnovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomePage();
  }
}
