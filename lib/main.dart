import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const KasirkuApp());
}

class KasirkuApp extends StatelessWidget {
  const KasirkuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kasirku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8FAF8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF126C55),
          brightness: Brightness.light,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
