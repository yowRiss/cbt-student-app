import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/api/api_client.dart';
import 'core/storage/local_exam_storage.dart';
import 'screens/login_screen.dart';
import 'screens/student_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi preferensi lokal
  await LocalExamStorage.init();

  // Set system UI overlay agar status bar Android terlihat modern dan menyatu
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const CbtStudentApp());
}

class CbtStudentApp extends StatefulWidget {
  const CbtStudentApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  State<CbtStudentApp> createState() => _CbtStudentAppState();
}

class _CbtStudentAppState extends State<CbtStudentApp> {
  @override
  void initState() {
    super.initState();
    ApiClient.onUnauthenticated = _handleUnauthenticated;
  }

  void _handleUnauthenticated() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = CbtStudentApp.navigatorKey.currentState;
      if (nav != null) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        CbtStudentApp.scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sesi login Anda telah berakhir. Silakan masuk kembali.',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final token = LocalExamStorage.getAuthToken();
    final bool hasToken = token != null && token.trim().isNotEmpty;

    return MaterialApp(
      navigatorKey: CbtStudentApp.navigatorKey,
      scaffoldMessengerKey: CbtStudentApp.scaffoldMessengerKey,
      title: 'CBT Ulangan SD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A), // Slate 900 Brand
          primary: const Color(0xFF0F172A),   // Architectural Dark Slate
          secondary: const Color(0xFFEA580C), // Sharp Orange Accent
          surface: Colors.white,
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFF8FAFC),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Pure Soft Slate 50
        fontFamily: 'sans-serif', // Native, super-fast, 0 overhead
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.8),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE2E8F0),
          thickness: 1,
          space: 1,
        ),
      ),
      home: hasToken ? const StudentHomeScreen() : const LoginScreen(),
    );
  }
}
