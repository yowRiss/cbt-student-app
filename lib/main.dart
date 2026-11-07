import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/storage/local_exam_storage.dart';
import 'screens/exam_list_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local preferences
  await LocalExamStorage.init();

  // Set system UI overlay (clean status bar)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const CbtStudentApp());
}

class CbtStudentApp extends StatelessWidget {
  const CbtStudentApp({super.key});

  @override
  Widget build(BuildContext context) {
    final bool hasToken = LocalExamStorage.getAuthToken() != null &&
        LocalExamStorage.getAuthToken()!.isNotEmpty;

    return MaterialApp(
      title: 'CBT Ulangan SD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A), // Deep Blue
          primary: const Color(0xFF1E3A8A),
          secondary: const Color(0xFF0284C7),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
      ),
      home: hasToken ? const ExamListScreen() : const LoginScreen(),
    );
  }
}
