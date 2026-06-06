import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/services_provider.dart';
import '../utils/services_excel_importer.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/theme_provider.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const XTypeGroup _excelTypeGroup = XTypeGroup(
    label: 'Excel',
    extensions: ['xlsx'],
    mimeTypes: ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
  );

  bool _isImportingServices = false;

  Future<void> _downloadServicesTemplate() async {
    final services = Provider.of<ServicesProvider>(context, listen: false).services;
    final rows = services
        .map(
          (service) => ServiceExcelRow(
            name: service.name,
            price: service.price,
            category: service.category,
          ),
        )
        .toList();
    final bytes = ServicesExcelImporter.buildTemplate(rows: rows);

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final directory = await getTemporaryDirectory();
        final tempFilePath = '${directory.path}/base_servicios.xlsx';
        final file = File(tempFilePath);
        await file.writeAsBytes(bytes);

        await Share.shareXFiles(
          [XFile(tempFilePath)],
          subject: 'Base de Servicios - Budapp',
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compartiendo base de servicios...'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar base: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      final saveLocation = await getSaveLocation(
        acceptedTypeGroups: const [_excelTypeGroup],
        suggestedName: 'base_servicios.xlsx',
      );

      if (saveLocation == null) return;

      final file = XFile.fromData(
        bytes,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        name: 'base_servicios.xlsx',
      );
      await file.saveTo(saveLocation.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Archivo de servicios descargado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _importServicesFromExcel() async {
    final selectedFile = await openFile(acceptedTypeGroups: const [_excelTypeGroup]);
    if (selectedFile == null) return;

    setState(() {
      _isImportingServices = true;
    });

    try {
      final bytes = await selectedFile.readAsBytes();
      final result = ServicesExcelImporter.parse(bytes);
      if (result.rows.isEmpty) {
        _showImportErrors(result.errors);
        return;
      }

      final importedCount = await Provider.of<ServicesProvider>(context, listen: false).importServices(result.rows);
      if (!mounted) return;

      final errorSummary = result.hasErrors ? ' Algunas filas se omitieron por errores.' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Se importaron $importedCount servicio${importedCount == 1 ? '' : 's'}.$errorSummary'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (result.hasErrors) {
        _showImportErrors(result.errors);
      }
    } catch (error) {
      if (!mounted) return;
      _showImportErrors(['No se pudo leer el archivo Excel seleccionado. Verifica que sea un .xlsx válido.']);
    } finally {
      if (mounted) {
        setState(() {
          _isImportingServices = false;
        });
      }
    }
  }

  void _showImportErrors(List<String> errors) {
    if (!mounted || errors.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Revisar importación'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: errors.take(8).map<Widget>((error) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• $error'),
                )).toList()
                  ..addAll(
                    errors.length > 8
                        ? [
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 8),
                              child: Text(
                                'Y ${errors.length - 8} error${errors.length - 8 == 1 ? '' : 'es'} más.',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            )
                          ]
                        : const [],
                  ),
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditDialog({ServiceItem? item}) {
    showDialog(
      context: context,
      builder: (context) => _AddEditServiceDialog(item: item),
    );
  }

  void _confirmDelete(ServiceItem item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('¿Eliminar servicio?'),
          content: Text('¿Estás seguro de que deseas eliminar "${item.name}"? Se borrará de tus servicios frecuentes.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Provider.of<ServicesProvider>(context, listen: false).deleteService(item.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Servicio eliminado'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Map<String, List<ServiceItem>> _groupServicesByCategory(List<ServiceItem> services) {
    final groupedServices = <String, List<ServiceItem>>{};
    for (final service in services) {
      groupedServices.putIfAbsent(service.category, () => []).add(service);
    }
    return groupedServices;
  }

  @override
  Widget build(BuildContext context) {
    final servicesProvider = Provider.of<ServicesProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final accentColor = themeProvider.lightAccent;
    final currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);
    final normalizedQuery = _searchQuery.toLowerCase();

    final filteredServices = servicesProvider.services.where((service) {
      return service.name.toLowerCase().contains(normalizedQuery) ||
          service.category.toLowerCase().contains(normalizedQuery);
    }).toList();
    final groupedServices = _groupServicesByCategory(filteredServices);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Base de Servicios'),
        actions: [
          IconButton(
            onPressed: _downloadServicesTemplate,
            tooltip: 'Descargar base Excel',
            icon: const Icon(Icons.download_outlined),
          ),
          IconButton(
            onPressed: _isImportingServices ? null : _importServicesFromExcel,
            tooltip: 'Importar servicios desde Excel',
            icon: _isImportingServices
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar servicio o categoría...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Services List
          Expanded(
            child: filteredServices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty ? Icons.engineering_outlined : Icons.search_off,
                          size: 64,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Aún no has guardado servicios frecuentes'
                              : 'No se encontraron servicios',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        if (_searchQuery.isEmpty)
                          Text(
                            'Agrega servicios por categoría para autocompletar tus presupuestos',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView(
                    children: groupedServices.entries.map((entry) {
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          leading: Icon(Icons.category_outlined, color: accentColor),
                          title: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${entry.value.length} servicio${entry.value.length == 1 ? '' : 's'}'),
                          children: entry.value.map((item) {
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: accentColor.withOpacity(0.08),
                                child: Icon(
                                  Icons.handyman_outlined,
                                  color: accentColor,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                item.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(item.category),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    currencyFormat.format(item.price),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _showAddEditDialog(item: item);
                                      } else if (value == 'delete') {
                                        _confirmDelete(item);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 18),
                                            SizedBox(width: 8),
                                            Text('Editar'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, color: Colors.red, size: 18),
                                            SizedBox(width: 8),
                                            Text('Eliminar', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        tooltip: 'Guardar Servicio',
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CreateCategoryDialog extends StatefulWidget {
  const _CreateCategoryDialog();

  @override
  State<_CreateCategoryDialog> createState() => _CreateCategoryDialogState();
}

class _CreateCategoryDialogState extends State<_CreateCategoryDialog> {
  final _categoryController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva categoría'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _categoryController,
          decoration: const InputDecoration(
            labelText: 'Nombre de la categoría',
            hintText: 'Ej. Soporte técnico',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category_outlined),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Por favor ingresa una categoría';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _categoryController.text.trim());
            }
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

class _AddEditServiceDialog extends StatefulWidget {
  final ServiceItem? item;

  const _AddEditServiceDialog({super.key, this.item});

  @override
  State<_AddEditServiceDialog> createState() => _AddEditServiceDialogState();
}

class _AddEditServiceDialogState extends State<_AddEditServiceDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  final _formKey = GlobalKey<FormState>();
  late String _selectedCategory;
  late List<String> _availableCategories;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ServicesProvider>(context, listen: false);
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _priceController = TextEditingController(
      text: widget.item != null ? widget.item!.price.toStringAsFixed(0) : '',
    );
    _selectedCategory = widget.item?.category ?? ServiceItem.defaultCategory;
    _availableCategories = <String>{...provider.categories, _selectedCategory}.toList()
      ..sort((a, b) {
        if (a == ServiceItem.defaultCategory) return -1;
        if (b == ServiceItem.defaultCategory) return 1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<String?> _showCreateCategoryDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => const _CreateCategoryDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final accentColor = themeProvider.lightAccent;

    return AlertDialog(
      title: Text(widget.item == null ? 'Nuevo Servicio Frecuente' : 'Editar Servicio'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: _availableCategories.map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      ).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, size: 28, color: accentColor),
                    tooltip: 'Nueva categoría',
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      final newCategory = await _showCreateCategoryDialog();
                      if (newCategory == null || newCategory.isEmpty) return;
                      setState(() {
                        _selectedCategory = newCategory;
                        _availableCategories = <String>{..._availableCategories, newCategory}.toList()
                          ..sort((a, b) {
                            if (a == ServiceItem.defaultCategory) return -1;
                            if (b == ServiceItem.defaultCategory) return 1;
                            return a.toLowerCase().compareTo(b.toLowerCase());
                          });
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Servicio',
                  hintText: 'Ej. Formateo PC + S.O.',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.handyman_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor ingresa un nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Precio sugerido (\$)',
                  hintText: 'Ej. 15000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor ingresa un precio';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price < 0) {
                    return 'Ingresa un precio válido mayor a 0';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final provider = Provider.of<ServicesProvider>(context, listen: false);
              final name = _nameController.text.trim();
              final price = double.parse(_priceController.text);

              if (widget.item == null) {
                provider.addService(name, price, _selectedCategory);
              } else {
                provider.updateService(widget.item!.id, name, price, _selectedCategory);
              }

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(widget.item == null ? 'Servicio guardado' : 'Servicio actualizado'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: Text(widget.item == null ? 'Guardar' : 'Actualizar'),
        ),
      ],
    );
  }
}

