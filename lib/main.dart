import 'package:flutter/material.dart';

import 'views/home_screen.dart';

void main() {
  runApp(const CryptoTrackerApp());
}

/// Widget gốc của ứng dụng Crypto Stream Tracker.
///
/// Thiết lập Material Design 3, bảng màu tài chính hiện đại (Indigo/Teal)
/// và điều hướng tới màn hình khởi đầu [HomeScreen].
class CryptoTrackerApp extends StatelessWidget {
  const CryptoTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crypto Stream Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A), // Blue Navy
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
