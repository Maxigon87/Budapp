import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/company_provider.dart';
import 'providers/services_provider.dart';
import 'providers/quotes_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/main_screen.dart';
import 'screens/welcome_screen.dart';

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
  await Hive.openBox('theme_settings');

  // Try initializing Firebase
  try {
    if (kIsWeb || Platform.isWindows) {
      // CONFIGURACIÓN DE FIREBASE PARA WINDOWS / WEB
      // IMPORTANTE: Para Windows/Web se debe registrar una "Web App" en la consola de Firebase.
      // Reemplaza 'YOUR_WEB_APP_ID' con el appId de la Web App registrada.
      const firebaseOptions = FirebaseOptions(
        apiKey: "AIzaSyCmBaNWCVu1cXP0F_-TnyA96Yg5NrZp-FY", 
        appId: "YOUR_WEB_APP_ID", // TODO: Cambiar por el ID de la App Web desde Firebase Console
        messagingSenderId: "562409321853",
        projectId: "mgz-app-98294",
        storageBucket: "mgz-app-98294.firebasestorage.app",
      );
      await Firebase.initializeApp(options: firebaseOptions);
    } else {
      // CONFIGURACIÓN DE FIREBASE PARA ANDROID / IOS
      // Lee automáticamente del archivo google-services.json o GoogleService-Info.plist
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint("Firebase not configured or initialized: $e");
    debugPrint("Running in Local Offline Mode.");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CompanyProvider()),
        ChangeNotifierProvider(create: (_) => ServicesProvider()),
        ChangeNotifierProvider(create: (_) => QuotesProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorAccent = themeProvider.lightAccent;

    // Stitch OLED Slate Design Tokens
    const colorBgDark = Color(0xFF0F131C);
    const colorSurface = Color(0xFF1C1F29);
    const colorSurfaceHigh = Color(0xFF262A34);
    const colorPrimary = Color(0xFF3B82F6);
    const colorSecondary = Color(0xFF4EDEA3);
    const colorTertiary = Color(0xFFFFB95F);
    const colorTextPrimary = Color(0xFFDFE2EF);
    const colorTextSecondary = Color(0xFFC2C6D6);
    const colorError = Color(0xFFFFB4AB);

    final appTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colorBgDark,
      colorScheme: ColorScheme.dark(
        primary: colorPrimary,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFF002E6A),
        onPrimaryContainer: const Color(0xFFADC6FF),
        secondary: colorSecondary,
        onSecondary: const Color(0xFF003824),
        secondaryContainer: const Color(0x3300A572),
        onSecondaryContainer: const Color(0xFF6FFBBE),
        tertiary: colorTertiary,
        onTertiary: const Color(0xFF472A00),
        tertiaryContainer: const Color(0x33CA8100),
        onTertiaryContainer: const Color(0xFFFFDDB8),
        surface: colorSurface,
        onSurface: colorTextPrimary,
        onSurfaceVariant: colorTextSecondary,
        error: colorError,
        onError: const Color(0xFF690005),
        outline: const Color(0xFF8C909F),
        outlineVariant: const Color(0xFF262A34),
      ),
      cardTheme: CardThemeData(
        color: colorSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF262A34), width: 1.0),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: colorBgDark,
        foregroundColor: colorTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colorTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorTextPrimary,
          side: const BorderSide(color: Color(0xFF262A34), width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF181B25),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF262A34), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF262A34), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: colorPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: colorError, width: 1),
        ),
        labelStyle: const TextStyle(color: colorTextSecondary, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: colorPrimary, fontWeight: FontWeight.bold),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xDA0F131C),
        elevation: 0,
        indicatorColor: colorPrimary.withOpacity(0.2),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: colorPrimary);
          }
          return const IconThemeData(color: colorTextSecondary);
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(color: colorPrimary, fontSize: 12, fontWeight: FontWeight.bold);
          }
          return const TextStyle(color: colorTextSecondary, fontSize: 12);
        }),
      ),
    );

    return MaterialApp(
        title: 'Budapp',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: appTheme,
        darkTheme: appTheme,
        
        // Localizations for datepicker and calendar widgets in Spanish
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'ES'),
        ],
        
        home: const WelcomeScreen(),
      );
  }
}
