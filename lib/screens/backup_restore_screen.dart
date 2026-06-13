import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';

import '../providers/company_provider.dart';
import '../providers/services_provider.dart';
import '../providers/materials_provider.dart';
import '../providers/quotes_provider.dart';
import '../providers/theme_provider.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _isExporting = false;
  bool _isImporting = false;

  static const XTypeGroup _jsonTypeGroup = XTypeGroup(
    label: 'JSON Backup',
    extensions: ['json'],
    mimeTypes: ['application/json'],
  );

  Future<void> _exportBackup() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final companyBox = Hive.box('company_settings');
      final servicesBox = Hive.box('services');
      final quotesBox = Hive.box('quotes');
      final materialsBox = Hive.box('materials');

      // 1. Gather company settings
      final Map<String, dynamic> companyData = {};
      for (var key in companyBox.keys) {
        companyData[key.toString()] = companyBox.get(key);
      }

      // 2. Gather services
      final List<Map<String, dynamic>> servicesData = [];
      for (var key in servicesBox.keys) {
        final val = servicesBox.get(key);
        if (val is Map) {
          servicesData.add(Map<String, dynamic>.from(val));
        }
      }

      // 3. Gather materials
      final List<Map<String, dynamic>> materialsData = [];
      for (var key in materialsBox.keys) {
        final val = materialsBox.get(key);
        if (val is Map) {
          materialsData.add(Map<String, dynamic>.from(val));
        }
      }

      // 4. Gather quotes
      final List<Map<String, dynamic>> quotesData = [];
      for (var key in quotesBox.keys) {
        final val = quotesBox.get(key);
        if (val is Map) {
          quotesData.add(Map<String, dynamic>.from(val));
        }
      }

      // 5. Construct complete backup object
      final backup = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'company_settings': companyData,
        'services': servicesData,
        'materials': materialsData,
        'quotes': quotesData,
      };

      final jsonString = jsonEncode(backup);
      final bytes = utf8.encode(jsonString);

      // Save/Share file
      final directory = await getTemporaryDirectory();
      final backupFilePath = '${directory.path}/respaldo_completo_budapp.json';
      final file = File(backupFilePath);
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(backupFilePath)],
        subject: 'Respaldo de Base de Datos - Budapp',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copia de seguridad compartida con éxito'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar copia de seguridad: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _importBackup() async {
    if (_isImporting) return;

    final selectedFile = await openFile(acceptedTypeGroups: const [_jsonTypeGroup]);
    if (selectedFile == null) return;

    // Ask user for confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 28),
              SizedBox(width: 12),
              Text('¿Importar respaldo?', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            '¡Atención! Esta acción reemplazará todos tus datos actuales (empresa, servicios y presupuestos) con los del archivo seleccionado. Esta acción no se puede deshacer.\n\n¿Estás seguro de que deseas continuar?',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí, Reemplazar'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _isImporting = true;
    });

    try {
      final fileContent = await selectedFile.readAsString();
      final Map<String, dynamic> backup = jsonDecode(fileContent) as Map<String, dynamic>;

      // Validate structure
      if (!backup.containsKey('company_settings') ||
          !backup.containsKey('services') ||
          !backup.containsKey('quotes')) {
        throw Exception('El archivo no es una copia de seguridad válida de Budapp.');
      }

      final companyBox = Hive.box('company_settings');
      final servicesBox = Hive.box('services');
      final quotesBox = Hive.box('quotes');
      final materialsBox = Hive.box('materials');

      // Clear current boxes
      await companyBox.clear();
      await servicesBox.clear();
      await quotesBox.clear();
      await materialsBox.clear();

      // 1. Restore company settings
      final companyData = backup['company_settings'] as Map<String, dynamic>;
      for (var entry in companyData.entries) {
        await companyBox.put(entry.key, entry.value);
      }

      // 2. Restore services
      final servicesData = backup['services'] as List;
      for (var item in servicesData) {
        if (item is Map) {
          final serviceMap = Map<String, dynamic>.from(item);
          final id = serviceMap['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
          await servicesBox.put(id, serviceMap);
        }
      }

      // 3. Restore materials
      if (backup.containsKey('materials')) {
        final materialsData = backup['materials'] as List;
        for (var item in materialsData) {
          if (item is Map) {
            final materialMap = Map<String, dynamic>.from(item);
            final id = materialMap['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
            await materialsBox.put(id, materialMap);
          }
        }
      }

      // 4. Restore quotes
      final quotesData = backup['quotes'] as List;
      for (var item in quotesData) {
        if (item is Map) {
          final quoteMap = Map<String, dynamic>.from(item);
          final id = quoteMap['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
          await quotesBox.put(id, quoteMap);
        }
      }

      // Refresh providers
      if (mounted) {
        await Provider.of<CompanyProvider>(context, listen: false).refresh();
        Provider.of<ServicesProvider>(context, listen: false).refresh();
        Provider.of<MaterialsProvider>(context, listen: false).refresh();
        Provider.of<QuotesProvider>(context, listen: false).refresh();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copia de seguridad restaurada con éxito'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al restaurar respaldo: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = themeProvider.lightAccent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Copias de Seguridad Offline'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // Header info card
          Card(
            elevation: 0,
            color: accentColor.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: accentColor.withOpacity(0.2), width: 1.2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Icon(Icons.sd_storage_outlined, size: 48, color: accentColor),
                  const SizedBox(height: 16),
                  Text(
                    'Respaldo Local Completo',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Esta opción te permite exportar un archivo con todos los datos de tu aplicación (perfil de empresa, logotipo, base de servicios y presupuestos) para guardarlo localmente o transferirlo a otro dispositivo sin necesidad de usar internet o una cuenta en la nube.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Actions list
          Text(
            'Acciones locales',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Export Card Button
          Card(
            child: InkWell(
              onTap: _isExporting ? null : _exportBackup,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.upload_outlined, color: accentColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Crear y Exportar Respaldo',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Genera un archivo .json con toda tu información para guardar o compartir.',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                    if (_isExporting)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Import Card Button
          Card(
            child: InkWell(
              onTap: _isImporting ? null : _importBackup,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.download_outlined, color: Color(0xFF16A34A)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Restaurar desde Respaldo',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Selecciona un archivo .json de respaldo para recuperar tus datos.',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                    if (_isImporting)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
