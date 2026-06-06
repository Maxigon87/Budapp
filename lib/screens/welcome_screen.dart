import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'auth_screen.dart';
import 'main_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isTestingConnection = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    });
  }

  Future<void> _testFirebaseConnection() async {
    if (_isTestingConnection) return;

    setState(() {
      _isTestingConnection = true;
    });

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text("Probando conexión con Firebase...")),
          ],
        ),
      ),
    );

    try {
      // 1. Verify if Firebase is initialized
      if (Firebase.apps.isEmpty) {
        throw Exception("Firebase no está inicializado. Asegúrate de tener configurado tu google-services.json.");
      }

      // 2. Perform a test write and read on Firestore with a timeout
      final firestore = FirebaseFirestore.instance;
      final testDocRef = firestore.collection('connection_tests').doc('test_connection');
      
      await testDocRef.set({
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'checking_reachability',
      }).timeout(const Duration(seconds: 6));

      final doc = await testDocRef.get().timeout(const Duration(seconds: 6));

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showResultDialog(
          success: true,
          title: "Conexión Exitosa",
          message: "¡Excelente! Firebase está completamente operativo. Se logró inicializar el SDK, escribir y leer un documento de prueba en Cloud Firestore.",
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        final errorStr = e.toString();
        if (errorStr.contains('permission-denied')) {
          // Firebase is connected but security rules rejected write (which is normal if not logged in)
          _showResultDialog(
            success: true,
            title: "Conexión Exitosa (Segura)",
            message: "¡Conexión parcial exitosa! La base de datos Firebase es accesible y respondió a la solicitud. (Fue bloqueada por Reglas de Seguridad, lo cual es correcto ya que no has iniciado sesión aún).",
          );
        } else {
          // Real connectivity/config error
          _showResultDialog(
            success: false,
            title: "Fallo de Conexión",
            message: "No se pudo conectar con Firebase.\n\nDetalles:\n$e\n\nVerifica:\n"
                "1. Haber creado la base de datos Firestore en tu consola de Firebase.\n"
                "2. Que tu archivo google-services.json esté actualizado y corresponda a tu Application ID.\n"
                "3. Conexión de red activa en el dispositivo.",
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  void _showResultDialog({required bool success, required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                color: success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: success ? const Color(0xFF1E3A8A) : const Color(0xFF6B7280),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("Entendido"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Logo Container
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/budapp-logo.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 96,
                        height: 96,
                        color: const Color(0xFF1E3A8A),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Presupuestos Text
                Text(
                  "Presupuestos",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),

                // Budapp Text (small)
                Text(
                  "Budapp",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.tertiary,
                    letterSpacing: 1.5,
                  ),
                ),

                const Spacer(flex: 2),

                // Action Buttons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Iniciar Sesión Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AuthScreen()),
                          );
                        },
                        icon: const Icon(Icons.login_outlined),
                        label: const Text(
                          "Iniciar Sesión / Crear Cuenta",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Invitado Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Bypasses authentication and enters app directly
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const MainScreen()),
                          );
                        },
                        icon: const Icon(Icons.person_outline),
                        label: const Text(
                          "Entrar como Invitado",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(flex: 1),

                // Firebase Test Button Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        "Configuración",
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                      ),
                    ),
                    Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                  ],
                ),
                const SizedBox(height: 16),

                // Firebase Connection Test Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton.icon(
                    onPressed: _testFirebaseConnection,
                    icon: const Icon(Icons.cloud_sync_outlined, color: Color(0xFF2563EB)),
                    label: const Text(
                      "Probar Conexión con Firebase",
                      style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB).withOpacity(0.08),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
