import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/materials_provider.dart';
import '../utils/materials_excel_importer.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/theme_provider.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const XTypeGroup _excelTypeGroup = XTypeGroup(
    label: 'Excel',
    extensions: ['xlsx'],
    mimeTypes: ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
  );

  bool _isImportingMaterials = false;

  Future<void> _downloadMaterialsTemplate() async {
    final materials = Provider.of<MaterialsProvider>(context, listen: false).materials;
    final rows = materials
        .map(
          (m) => MaterialExcelRow(
            nombre: m.nombre,
            unidad: m.unidad,
            ultimoPrecio: m.ultimoPrecio,
          ),
        )
        .toList();
    final bytes = MaterialsExcelImporter.buildTemplate(rows: rows);

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final directory = await getTemporaryDirectory();
        final tempFilePath = '${directory.path}/materiales.xlsx';
        final file = File(tempFilePath);
        await file.writeAsBytes(bytes);

        await Share.shareXFiles(
          [XFile(tempFilePath)],
          subject: 'Base de Materiales - Budapp',
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compartiendo base de materiales...'),
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
        suggestedName: 'materiales.xlsx',
      );

      if (saveLocation == null) return;

      final file = XFile.fromData(
        bytes,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        name: 'materiales.xlsx',
      );
      await file.saveTo(saveLocation.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Archivo de materiales descargado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _importMaterialsFromExcel() async {
    final selectedFile = await openFile(acceptedTypeGroups: const [_excelTypeGroup]);
    if (selectedFile == null) return;

    setState(() {
      _isImportingMaterials = true;
    });

    try {
      final bytes = await selectedFile.readAsBytes();
      final result = MaterialsExcelImporter.parse(bytes);
      if (result.rows.isEmpty) {
        _showImportErrors(result.errors);
        return;
      }

      if (!mounted) return;
      final provider = Provider.of<MaterialsProvider>(context, listen: false);
      final timestamp = DateTime.now().microsecondsSinceEpoch;

      final currentMaterials = provider.materials;
      final materialMap = <String, MaterialItem>{};
      for (final m in currentMaterials) {
        final key = '${m.unidad.trim().toLowerCase()}_${m.nombre.trim().toLowerCase()}';
        materialMap[key] = m;
      }

      final importedItems = <MaterialItem>[];
      for (var index = 0; index < result.rows.length; index++) {
        final row = result.rows[index];
        final key = '${row.unidad.trim().toLowerCase()}_${row.nombre.trim().toLowerCase()}';
        final existing = materialMap[key];

        if (existing != null) {
          final updated = MaterialItem(
            id: existing.id,
            nombre: existing.nombre,
            unidad: existing.unidad,
            ultimoPrecio: row.ultimoPrecio ?? existing.ultimoPrecio,
          );
          importedItems.add(updated);
        } else {
          final id = '${timestamp}_$index';
          final newItem = MaterialItem(
            id: id,
            nombre: row.nombre,
            unidad: row.unidad,
            ultimoPrecio: row.ultimoPrecio,
          );
          importedItems.add(newItem);
        }
      }

      await provider.saveMaterials(importedItems);

      if (!mounted) return;
      final importedCount = importedItems.length;
      final errorSummary = result.hasErrors ? ' Algunas filas se omitieron por errores.' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Se importaron $importedCount material${importedCount == 1 ? '' : 'es'}.$errorSummary'),
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
          _isImportingMaterials = false;
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

  void _showAddEditDialog({MaterialItem? item}) {
    showDialog(
      context: context,
      builder: (context) => _AddEditMaterialDialog(item: item),
    );
  }

  void _confirmDelete(MaterialItem item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('¿Eliminar material?'),
          content: Text('¿Estás seguro de que deseas eliminar "${item.nombre}"? Se borrará de tus materiales frecuentes.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Provider.of<MaterialsProvider>(context, listen: false).deleteMaterial(item.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Material eliminado'),
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

  Map<String, List<MaterialItem>> _groupMaterialsByUnidad(List<MaterialItem> materials) {
    final grouped = <String, List<MaterialItem>>{};
    for (final mat in materials) {
      final key = mat.unidad.isEmpty ? 'Sin unidad' : mat.unidad;
      grouped.putIfAbsent(key, () => []).add(mat);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final materialsProvider = Provider.of<MaterialsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final accentColor = themeProvider.lightAccent;
    final currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);
    final normalizedQuery = _searchQuery.toLowerCase();

    final filteredMaterials = materialsProvider.materials.where((m) {
      return m.nombre.toLowerCase().contains(normalizedQuery) ||
          m.unidad.toLowerCase().contains(normalizedQuery);
    }).toList();
    final groupedMaterials = _groupMaterialsByUnidad(filteredMaterials);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Base de Materiales'),
        actions: [
          IconButton(
            onPressed: _downloadMaterialsTemplate,
            tooltip: 'Exportar Materiales',
            icon: const Icon(Icons.download_outlined),
          ),
          IconButton(
            onPressed: _isImportingMaterials ? null : _importMaterialsFromExcel,
            tooltip: 'Importar materiales desde Excel',
            icon: _isImportingMaterials
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
                hintText: 'Buscar material o unidad...',
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

          // Materials List
          Expanded(
            child: filteredMaterials.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty ? Icons.inventory_2_outlined : Icons.search_off,
                          size: 64,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Aún no has guardado materiales frecuentes'
                              : 'No se encontraron materiales',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        if (_searchQuery.isEmpty)
                          Text(
                            'Agrega materiales para autocompletar tus presupuestos',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView(
                    children: groupedMaterials.entries.map((entry) {
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: ExpansionTile(
                          key: Key('${entry.key}_${_searchQuery.isNotEmpty}'),
                          initiallyExpanded: _searchQuery.isNotEmpty,
                          leading: Icon(Icons.shopping_bag_outlined, color: accentColor),
                          title: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${entry.value.length} material${entry.value.length == 1 ? '' : 'es'}'),
                          children: entry.value.asMap().entries.map((itemEntry) {
                            final index = itemEntry.key;
                            final item = itemEntry.value;
                            final hasPrice = item.ultimoPrecio != null;
                            return Column(
                              children: [
                                if (index > 0)
                                  Divider(
                                    height: 1,
                                    thickness: 0.5,
                                    indent: 16,
                                    endIndent: 16,
                                    color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                                  ),
                                ListTile(
                                  title: Text(
                                    item.nombre,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text('Medida: ${item.unidad}'),
                                      const SizedBox(height: 2),
                                      Text(
                                        hasPrice
                                            ? 'Último precio: ${currencyFormat.format(item.ultimoPrecio)}'
                                            : 'Sin precio de referencia',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: hasPrice ? FontWeight.bold : FontWeight.normal,
                                          color: hasPrice
                                              ? Theme.of(context).colorScheme.primary
                                              : Theme.of(context).colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
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
                                ),
                              ],
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
        tooltip: 'Guardar Material',
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CreateUnitDialog extends StatefulWidget {
  const _CreateUnitDialog();

  @override
  State<_CreateUnitDialog> createState() => _CreateUnitDialogState();
}

class _CreateUnitDialogState extends State<_CreateUnitDialog> {
  final _unitController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva unidad de medida'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _unitController,
          decoration: const InputDecoration(
            labelText: 'Unidad de medida',
            hintText: 'Ej. Metro, Unidad, Litro',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.straighten_outlined),
          ),
          textCapitalization: TextCapitalization.sentences,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Por favor ingresa una unidad';
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
              Navigator.pop(context, _unitController.text.trim());
            }
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

class _AddEditMaterialDialog extends StatefulWidget {
  final MaterialItem? item;

  const _AddEditMaterialDialog({super.key, this.item});

  @override
  State<_AddEditMaterialDialog> createState() => _AddEditMaterialDialogState();
}

class _AddEditMaterialDialogState extends State<_AddEditMaterialDialog> {
  late final TextEditingController _nombreController;
  late final TextEditingController _precioController;
  final _formKey = GlobalKey<FormState>();
  late String _selectedUnidad;
  late List<String> _availableUnidades;

  static const String defaultUnidad = 'Unidad';

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<MaterialsProvider>(context, listen: false);
    _nombreController = TextEditingController(text: widget.item?.nombre ?? '');
    _precioController = TextEditingController(
      text: widget.item?.ultimoPrecio != null ? widget.item!.ultimoPrecio!.toStringAsFixed(0) : '',
    );
    _selectedUnidad = widget.item?.unidad ?? defaultUnidad;
    _availableUnidades = <String>{...provider.unidades, _selectedUnidad, defaultUnidad, 'Metro'}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<String?> _showCreateUnitDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => const _CreateUnitDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final accentColor = themeProvider.lightAccent;

    return AlertDialog(
      title: Text(widget.item == null ? 'Nuevo Material Frecuente' : 'Editar Material'),
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
                      value: _selectedUnidad,
                      decoration: const InputDecoration(
                        labelText: 'Unidad de medida',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.straighten_outlined),
                      ),
                      items: _availableUnidades.map(
                        (u) => DropdownMenuItem(
                          value: u,
                          child: Text(u),
                        ),
                      ).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedUnidad = value;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, size: 28, color: accentColor),
                    tooltip: 'Nueva unidad',
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      final newUnit = await _showCreateUnitDialog();
                      if (newUnit == null || newUnit.isEmpty) return;
                      setState(() {
                        _selectedUnidad = newUnit;
                        _availableUnidades = <String>{..._availableUnidades, newUnit}.toList()
                          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Material',
                  hintText: 'Ej. Cable 2.5 mm',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
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
                controller: _precioController,
                decoration: const InputDecoration(
                  labelText: 'Precio de referencia (\$, opcional)',
                  hintText: 'Ej. 1200',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final price = double.tryParse(value);
                    if (price == null || price < 0) {
                      return 'Ingresa un precio válido mayor a 0';
                    }
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
              final provider = Provider.of<MaterialsProvider>(context, listen: false);
              final nombre = _nombreController.text.trim();
              final priceText = _precioController.text.trim();
              final price = priceText.isNotEmpty ? double.parse(priceText) : null;

              if (widget.item == null) {
                provider.addMaterial(nombre, _selectedUnidad, price);
              } else {
                provider.updateMaterial(widget.item!.id, nombre, _selectedUnidad, price);
              }

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(widget.item == null ? 'Material guardado' : 'Material actualizado'),
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
