import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:penjanje/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Penjački savez BiH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF1565C0),
          surface: const Color(0xFF152233),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}