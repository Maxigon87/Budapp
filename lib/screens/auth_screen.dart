import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/company_provider.dart';
import '../providers/services_provider.dart';
import '../providers/quotes_provider.dart';
import 'main_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUpMode = false;
  bool _isObscured = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleAuthAction() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    String? error;
    if (_isSignUpMode) {
      error = await authProvider.signUp(email, password);
    } else {
      error = await authProvider.signIn(email, password);
    }

    if (error == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isSignUpMode ? 'Cuenta creada con éxito' : 'Sesión iniciada con éxito'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Show Dialog to choose sync option
        _showPostAuthSyncDialog();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _syncData(bool upload) async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
    final quotesProvider = Provider.of<QuotesProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Sincronizando datos..."),
          ],
        ),
      ),
    );

    try {
      if (upload) {
        await companyProvider.uploadToCloud().timeout(const Duration(seconds: 10));
        await servicesProvider.uploadToCloud().timeout(const Duration(seconds: 15));
        await quotesProvider.uploadToCloud().timeout(const Duration(seconds: 15));
      } else {
        await companyProvider.syncFromCloud().timeout(const Duration(seconds: 10));
        await servicesProvider.syncFromCloud().timeout(const Duration(seconds: 15));
        await quotesProvider.syncFromCloud().timeout(const Duration(seconds: 15));
      }
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(upload
                ? 'Datos respaldados en la nube con éxito'
                : 'Datos restaurados de la nube con éxito'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Navigate to MainScreen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        String errorMessage = 'Error de sincronización: $e';
        if (e.toString().contains('TimeoutException')) {
          errorMessage = 'La sincronización tardó demasiado. Por favor, verifica tu conexión a internet o los permisos de base de datos.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Still proceed to app even if sync fails
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showPostAuthSyncDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Sincronización de Datos',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            '¿Cómo deseas proceder con tus datos?\n\n'
            '• RESPALDAR LOCALES: Sube tus datos de este dispositivo a la nube.\n'
            '• RESTAURAR DESDE NUBE: Descarga los datos de tu cuenta a este dispositivo.\n'
            '• MANTENER SEPARADO: Entra directamente sin sincronizar por ahora.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const MainScreen()),
                  (route) => false,
                );
              },
              child: const Text('Ignorar', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                _syncData(false);
              },
              child: const Text('Restaurar desde Nube'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
              onPressed: () {
                Navigator.pop(context);
                _syncData(true);
              },
              child: const Text('Respaldar Locales'),
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
      appBar: AppBar(
        title: Text(_isSignUpMode ? 'Crear Cuenta' : 'Iniciar Sesión'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon header
                  Icon(
                    _isSignUpMode ? Icons.person_add_outlined : Icons.lock_outline,
                    size: 64,
                    color: const Color(0xFF1E3A8A),
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    _isSignUpMode 
                        ? 'Únete a Budapp para guardar tus presupuestos en la nube.'
                        : 'Accede a tu cuenta para sincronizar tus datos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 32),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Correo Electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa tu correo electrónico';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                        return 'Ingresa un correo electrónico válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _isObscured,
                    decoration: InputDecoration(
                      labelText: 'Contraseña (mín. 6 caracteres)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_isObscured ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setState(() {
                            _isObscured = !_isObscured;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa tu contraseña';
                      }
                      if (value.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Submit button
                  if (authProvider.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _handleAuthAction,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _isSignUpMode ? 'Registrarse y Entrar' : 'Iniciar Sesión',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Toggle mode button
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUpMode = !_isSignUpMode;
                      });
                    },
                    child: Text(
                      _isSignUpMode 
                          ? '¿Ya tienes una cuenta? Inicia sesión aquí' 
                          : '¿No tienes cuenta? Regístrate aquí',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
