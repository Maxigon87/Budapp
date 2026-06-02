import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/company_provider.dart';
import 'providers/services_provider.dart';
import 'providers/quotes_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/main_screen.dart';

import 'package:flutter/foundation.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();
  
  // Open Hive Boxes
  await Hive.openBox('company_settings');
  await Hive.openBox('services');
  await Hive.openBox('quotes');

  // Try initializing Firebase
  try {
    if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyCmBaNWCVu1cXP0F_-TnyA96Yg5NrZp-FY",
          appId: "1:562409321853:android:fbeb58efb907a2c5108814",
          messagingSenderId: "562409321853",
          projectId: "mgz-app-98294",
          storageBucket: "mgz-app-98294.firebasestorage.app",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint("Firebase not configured or initialized: $e");
    debugPrint("Running in Local Offline Mode.");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Slate/Blue corporate design colors
    const colorBgLight = Color(0xFFF8FAFC);
    const colorCardLight = Colors.white;
    const colorPrimary = Color(0xFF0F172A); // Slate 900
    const colorSecondary = Color(0xFF1E293B); // Slate 800
    const colorAccent = Color(0xFF2563EB); // Blue 600
    const colorTextPrimary = Color(0xFF111827); // Gray 900
    const colorTextSecondary = Color(0xFF6B7280); // Gray 500
    const colorError = Color(0xFFDC2626); // Red 600

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CompanyProvider()),
        ChangeNotifierProvider(create: (_) => ServicesProvider()),
        ChangeNotifierProvider(create: (_) => QuotesProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Generador de Presupuestos',
        debugShowCheckedModeBanner: false,
        
        // Theme settings
        themeMode: ThemeMode.system,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: colorBgLight,
          colorScheme: const ColorScheme.light(
            primary: colorPrimary,
            onPrimary: Colors.white,
            secondary: colorSecondary,
            onSecondary: Colors.white,
            tertiary: colorAccent,
            onTertiary: Colors.white,
            surface: colorCardLight,
            onSurface: colorTextPrimary,
            error: colorError,
            onError: Colors.white,
            outlineVariant: Color(0xFFE2E8F0),
          ),
          
          // Modern, clean, thin border card theme (Notion/Linear style)
          cardTheme: CardThemeData(
            color: colorCardLight,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
            ),
            margin: const EdgeInsets.symmetric(vertical: 4),
          ),

          // Clean flat app bars
          appBarTheme: const AppBarTheme(
            backgroundColor: colorBgLight,
            foregroundColor: colorTextPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            titleTextStyle: TextStyle(
              color: colorTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          // Modern primary corporate button style
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: colorAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),

          // Clean outlined buttons
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: colorPrimary,
              side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),

          // Modern Stripe/Linear inputs style
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: colorAccent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: colorError, width: 1),
            ),
            labelStyle: const TextStyle(color: colorTextSecondary, fontSize: 14),
            floatingLabelStyle: const TextStyle(color: colorAccent, fontWeight: FontWeight.bold),
          ),

          // Bottom navigation bar styling
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            elevation: 0,
            indicatorColor: colorAccent.withOpacity(0.08),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            iconTheme: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return const IconThemeData(color: colorAccent);
              }
              return const IconThemeData(color: colorTextSecondary);
            }),
            labelTextStyle: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return const TextStyle(color: colorAccent, fontSize: 12, fontWeight: FontWeight.bold);
              }
              return const TextStyle(color: colorTextSecondary, fontSize: 12);
            }),
          ),
        ),

        // Dark theme (Supporting corresponding slate shades)
        darkTheme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
          colorScheme: const ColorScheme.dark(
            primary: Colors.white,
            onPrimary: Color(0xFF0F172A),
            secondary: Color(0xFF334155), // Slate 700
            onSecondary: Colors.white,
            tertiary: Color(0xFF3B82F6), // Blue 500
            onTertiary: Colors.white,
            surface: Color(0xFF1E293B), // Slate 800
            onSurface: Colors.white,
            error: Color(0xFFEF4444),
            onError: Colors.white,
            outlineVariant: Color(0xFF334155),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF1E293B),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFF334155), width: 1.0),
            ),
            margin: const EdgeInsets.symmetric(vertical: 4),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0F172A),
            foregroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF334155)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
            ),
          ),
        ),
        
        // Localizations for datepicker and calendar widgets in Spanish
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'ES'),
        ],
        
        home: const MainScreen(),
      ),
    );
  }
}
