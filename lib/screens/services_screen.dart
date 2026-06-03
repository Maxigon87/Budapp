import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/services_provider.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  static const String _addCategoryOption = '__add_category__';

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String?> _showCreateCategoryDialog() async {
    final categoryController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final category = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nueva categoría'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: categoryController,
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
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, categoryController.text.trim());
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );

    categoryController.dispose();
    return category;
  }

  void _showAddEditDialog({ServiceItem? item}) {
    final provider = Provider.of<ServicesProvider>(context, listen: false);
    final nameController = TextEditingController(text: item?.name ?? '');
    // Format price to integer string for easier typing
    final priceController = TextEditingController(
      text: item != null ? item.price.toStringAsFixed(0) : '',
    );
    final formKey = GlobalKey<FormState>();
    var selectedCategory = item?.category ?? ServiceItem.defaultCategory;
    var availableCategories = <String>{...provider.categories, selectedCategory}.toList()
      ..sort((a, b) {
        if (a == ServiceItem.defaultCategory) return -1;
        if (b == ServiceItem.defaultCategory) return 1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(item == null ? 'Nuevo Servicio Frecuente' : 'Editar Servicio'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: [
                          ...availableCategories.map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: _addCategoryOption,
                            child: Text('+ Agregar categoría'),
                          ),
                        ],
                        onChanged: (value) async {
                          if (value == null) return;
                          if (value == _addCategoryOption) {
                            final newCategory = await _showCreateCategoryDialog();
                            if (newCategory == null || newCategory.isEmpty) return;
                            setDialogState(() {
                              selectedCategory = newCategory;
                              availableCategories = <String>{...availableCategories, newCategory}.toList()
                                ..sort((a, b) {
                                  if (a == ServiceItem.defaultCategory) return -1;
                                  if (b == ServiceItem.defaultCategory) return 1;
                                  return a.toLowerCase().compareTo(b.toLowerCase());
                                });
                            });
                            return;
                          }
                          setDialogState(() {
                            selectedCategory = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
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
                        controller: priceController,
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
                    if (formKey.currentState!.validate()) {
                      final provider = Provider.of<ServicesProvider>(context, listen: false);
                      final name = nameController.text.trim();
                      final price = double.parse(priceController.text);

                      if (item == null) {
                        provider.addService(name, price, selectedCategory);
                      } else {
                        provider.updateService(item.id, name, price, selectedCategory);
                      }

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(item == null ? 'Servicio guardado' : 'Servicio actualizado'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: Text(item == null ? 'Guardar' : 'Actualizar'),
                ),
              ],
            );
          },
        );
      },
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
                          leading: const Icon(Icons.category_outlined, color: Color(0xFF2563EB)),
                          title: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${entry.value.length} servicio${entry.value.length == 1 ? '' : 's'}'),
                          children: entry.value.map((item) {
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF2563EB).withOpacity(0.08),
                                child: const Icon(
                                  Icons.handyman_outlined,
                                  color: Color(0xFF2563EB),
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
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.add),
      ),
    );
  }
}
