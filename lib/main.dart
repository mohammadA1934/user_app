import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'ui/login_page.dart';

// Supabase config (مفتاح anon آمن للاستخدام داخل التطبيق)
const String kSupabaseUrl = 'https://htjlgznnvbdpffadunmc.supabase.co';
const String kSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh0amxnem5udmJkcGZmYWR1bm1jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg0MTIxNzIsImV4cCI6MjA3Mzk4ODE3Mn0.NrRYAYCFQRGQsQMEd6GIaJv-PAOtBydO7XEKGxUKKf0';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // لو صار خطأ أثناء التهيئة، اطبعه ولا توقف تشغيل التطبيق
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // للمساعدة في التشخيص
    // ignore: avoid_print
    print('FlutterError: ${details.exception}\n${details.stack}');
  };

  try {
    // نهيئة الخدمتين مع مهلة حتى لا يعلق الإقلاع
    await Future.wait([
      Supabase.initialize(
        url: kSupabaseUrl,
        anonKey: kSupabaseAnonKey,
      ),
      Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),
    ]).timeout(const Duration(seconds: 12));
  } catch (e, st) {
    // ignore: avoid_print
    print('Init failed: $e\n$st');
    // نكمل تشغيل التطبيق حتى لو فشلت خدمة ما
  }

  runApp(const ShoppinestApp());
}

class ShoppinestApp extends StatelessWidget {
  const ShoppinestApp({super.key});

  static const Color kPrimary = Color(0xFF2ECC95);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shoppinest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimary,
          primary: kPrimary,
        ),
        fontFamily: 'Roboto',
      ),
      home: const LoginPage(),
    );
  }
}
