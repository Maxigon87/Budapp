import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/company_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/services_provider.dart';
import '../providers/materials_provider.dart';
import '../providers/quotes_provider.dart';
import '../providers/theme_provider.dart';
import 'backup_restore_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Company Profile Controllers
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;
  String? _logoPath;

  // Firebase Auth Controllers
  final _authEmailController = TextEditingController();
  final _authPasswordController = TextEditingController();
  bool _isSignUpMode = false;

  @override
  void initState() {
    super.initState();
    final company = Provider.of<CompanyProvider>(context, listen: false);
    _nameController = TextEditingController(text: company.name);
    _addressController = TextEditingController(text: company.address);
    _phoneController = TextEditingController(text: company.phone);
    _emailController = TextEditingController(text: company.email);
    _websiteController = TextEditingController(text: company.website);
    _logoPath = company.logoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _authEmailController.dispose();
    _authPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _logoPath = pickedFile.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imagen: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _showSaveSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 28),
              SizedBox(width: 12),
              Text('¡Guardado con éxito!', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Los datos del perfil de tu empresa y el logo han sido guardados localmente y sincronizados en la nube correctamente.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _saveCompanyInfo() async {
    if (_formKey.currentState!.validate()) {
      // Show loading dialog to block input during sync
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Guardando y sincronizando datos..."),
            ],
          ),
        ),
      );

      try {
        await Provider.of<CompanyProvider>(context, listen: false).updateCompanyInfo(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          website: _websiteController.text.trim(),
          logoPath: _logoPath,
        );

        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          _showSaveSuccessDialog(); // Show success modal dialog
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al guardar datos: $e'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _handleAuthAction() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final email = _authEmailController.text.trim();
    final password = _authPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa el correo y la contraseña'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    String? error;
    if (_isSignUpMode) {
      error = await authProvider.signUp(email, password);
    } else {
      error = await authProvider.signIn(email, password);
    }

    if (error == null) {
      // Success
      _authEmailController.clear();
      _authPasswordController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isSignUpMode ? 'Cuenta creada con éxito' : 'Sesión iniciada con éxito'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Ask user to sync
        _showPostAuthSyncDialog();
      }
    } else {
      // Error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: const Color(0xFFDC2626), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _syncData(bool upload) async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
    final materialsProvider = Provider.of<MaterialsProvider>(context, listen: false);
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
        debugPrint("Starting upload: Company Settings...");
        await companyProvider.uploadToCloud().timeout(const Duration(seconds: 10));
        
        debugPrint("Starting upload: Services...");
        await servicesProvider.uploadToCloud().timeout(const Duration(seconds: 15));

        debugPrint("Starting upload: Materials...");
        await materialsProvider.uploadToCloud().timeout(const Duration(seconds: 15));
        
        debugPrint("Starting upload: Quotes...");
        await quotesProvider.uploadToCloud().timeout(const Duration(seconds: 15));
      } else {
        debugPrint("Starting download: Company Settings...");
        await companyProvider.syncFromCloud().timeout(const Duration(seconds: 10));
        
        debugPrint("Starting download: Services...");
        await servicesProvider.syncFromCloud().timeout(const Duration(seconds: 15));

        debugPrint("Starting download: Materials...");
        await materialsProvider.syncFromCloud().timeout(const Duration(seconds: 15));
        
        debugPrint("Starting download: Quotes...");
        await quotesProvider.syncFromCloud().timeout(const Duration(seconds: 15));
      }
      
      debugPrint("Sync completed successfully!");
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
      }
    } catch (e) {
      debugPrint("Sync error details: $e");
      String errorMessage = 'Error de sincronización: $e';
      if (e.toString().contains('TimeoutException')) {
        errorMessage = 'La sincronización tardó demasiado. Por favor, verifica tu conexión a internet o los permisos de base de datos.';
      }
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
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
          title: const Text('Sincronización de Datos'),
          content: const Text(
            'Has iniciado sesión correctamente. ¿Cómo deseas proceder con tus datos?\n\n'
            '• RESPALDAR LOCALES: Sube tus datos de este dispositivo a la nube.\n'
            '• RESTAURAR DESDE NUBE: Descarga los datos de tu cuenta a este dispositivo.\n'
            '• MANTENER SEPARADO: Entra sin sincronizar por ahora.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
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
    final companyProvider = Provider.of<CompanyProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Section 1: Company Profile Form
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Perfil de la Empresa / Técnico',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 16),

                    // Logo Picker Section
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                            backgroundImage: _logoPath != null ? FileImage(File(_logoPath!)) : null,
                            child: _logoPath == null
                                ? Icon(
                                    Icons.business,
                                    size: 40,
                                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              backgroundColor: const Color(0xFF2563EB),
                              radius: 16,
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                onPressed: _pickLogo,
                              ),
                            ),
                          ),
                          if (_logoPath != null)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: CircleAvatar(
                                backgroundColor: const Color(0xFFDC2626),
                                radius: 14,
                                child: IconButton(
                                  icon: const Icon(Icons.close, size: 12, color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      _logoPath = null;
                                    });
                                    companyProvider.clearLogo();
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Form Fields
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre Comercial *',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Ingresa el nombre comercial' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Dirección Comercial *',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Ingresa la dirección' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono de Contacto *',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Ingresa el teléfono' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico *',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa el correo electrónico';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Ingresa un correo electrónico válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _websiteController,
                      decoration: const InputDecoration(
                        labelText: 'Sitio Web (Opcional)',
                        prefixIcon: Icon(Icons.language_outlined),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saveCompanyInfo,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Guardar Datos Perfil'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: Firebase Cloud Sync (Version 4)
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sincronización en la Nube (Firebase)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Respalda tus presupuestos y base de servicios de forma segura para recuperarlos en cualquier dispositivo.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const Divider(height: 24),

                  if (authProvider.isAuthenticated) ...[
                    // Logged in state
                    Row(
                      children: [
                        const Icon(Icons.cloud_done_outlined, color: Color(0xFF16A34A)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Sesión Iniciada",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                authProvider.user?.email ?? '',
                                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => authProvider.signOut(),
                          child: const Text('Salir', style: TextStyle(color: Color(0xFFDC2626))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Backup and Restore Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _syncData(false), // Restore / Download
                            icon: const Icon(Icons.cloud_download_outlined),
                            label: const Text("Restaurar"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _syncData(true), // Backup / Upload
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text("Respaldar"),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Logged out / offline state
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isSignUpMode ? 'Crear Cuenta' : 'Iniciar Sesión',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isSignUpMode = !_isSignUpMode;
                            });
                          },
                          child: Text(_isSignUpMode ? '¿Ya tienes cuenta? Ingresa' : '¿No tienes cuenta? Regístrate'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _authEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _authPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña (mín. 6 caracteres)',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),

                    if (authProvider.isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _handleAuthAction,
                          icon: Icon(_isSignUpMode ? Icons.person_add_outlined : Icons.login_outlined),
                          label: Text(_isSignUpMode ? 'Registrarse y Conectar' : 'Iniciar Sesión'),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          // Section 3: Offline Local Backup
          const SizedBox(height: 16),
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Copia de Seguridad Offline (Local)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Exporta o restaura toda tu base de datos (empresa, servicios y presupuestos) de forma local sin usar internet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const Divider(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const BackupRestoreScreen()),
                        );
                      },
                      icon: const Icon(Icons.sd_storage_outlined),
                      label: const Text('Gestionar Copias Locales'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 4: Color customization
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aspecto y Personalización',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Elige el color principal de la aplicación para adaptarlo a la identidad de tu empresa.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const Divider(height: 24),
                  
                  // Horizontal color list picker
                  SizedBox(
                    height: 56,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: ThemeProvider.themeColors.length,
                      itemBuilder: (context, index) {
                        final themeColor = ThemeProvider.themeColors[index];
                        final isSelected = themeProvider.colorIndex == index;
                        final colorAccentColor = themeColor.lightColor;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                          child: InkWell(
                            onTap: () {
                              themeProvider.setColorIndex(index);
                            },
                            borderRadius: BorderRadius.circular(28),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: colorAccentColor.withOpacity(0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? colorAccentColor : Theme.of(context).colorScheme.outlineVariant,
                                  width: isSelected ? 3.0 : 1.5,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: colorAccentColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 14,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Color seleccionado: ${themeProvider.currentThemeColor.name}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
