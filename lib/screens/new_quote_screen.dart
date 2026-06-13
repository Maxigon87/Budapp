import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/quotes_provider.dart';
import '../providers/services_provider.dart';
import '../providers/materials_provider.dart';
import '../providers/company_provider.dart';
import '../utils/pdf_generator.dart';
import 'package:printing/printing.dart';
import '../providers/theme_provider.dart';

class NewQuoteScreen extends StatefulWidget {
  const NewQuoteScreen({super.key});

  @override
  State<NewQuoteScreen> createState() => _NewQuoteScreenState();
}

class _NewQuoteScreenState extends State<NewQuoteScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Client Info Controllers
  final _clientNameController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _clientAddressController = TextEditingController();
  final _observationsController = TextEditingController();
  
  // Custom metadata
  late String _quoteNumber;
  late DateTime _quoteDate;
  
  // Selected items in current quote
  final List<QuoteItem> _quoteItems = [];
  
  // Add item form controllers
  final _serviceNameController = TextEditingController();
  final _servicePriceController = TextEditingController();
  final _serviceNameFocusNode = FocusNode();
  String _selectedServiceCategory = 'Todas';
  bool _isSaving = false;

  // Add material form controllers
  final _materialNameController = TextEditingController();
  final _materialPriceController = TextEditingController();
  final _materialNameFocusNode = FocusNode();
  MaterialItem? _selectedMaterialFromAutocomplete;

  @override
  void initState() {
    super.initState();
    _quoteDate = DateTime.now();
    // Retrieve next budget number automatically from provider
    final quotesProvider = Provider.of<QuotesProvider>(context, listen: false);
    _quoteNumber = quotesProvider.getNextQuoteNumber();
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _clientAddressController.dispose();
    _observationsController.dispose();
    _serviceNameController.dispose();
    _servicePriceController.dispose();
    _serviceNameFocusNode.dispose();
    _materialNameController.dispose();
    _materialPriceController.dispose();
    _materialNameFocusNode.dispose();
    super.dispose();
  }

  double get _totalAmount {
    return _quoteItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  double get _servicesTotal {
    return _quoteItems.where((i) => !i.isMaterial).fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  double get _materialsTotal {
    return _quoteItems.where((i) => i.isMaterial).fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  void _addServiceItem() {
    final name = _serviceNameController.text.trim();
    final priceStr = _servicePriceController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el nombre del servicio'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final price = double.tryParse(priceStr) ?? 0.0;
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un precio válido mayor a 0'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    _showQuantityDialog(name, price);
  }

  void _showQuantityDialog(String name, double price) {
    final quantityController = TextEditingController(text: '1');
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cantidad del Servicio'),
          content: Form(
            key: dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text('Precio unitario: \$${price.toStringAsFixed(0)}'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa la cantidad';
                    }
                    final qty = int.tryParse(value);
                    if (qty == null || qty <= 0) {
                      return 'Cantidad inválida (mayor a 0)';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (dialogFormKey.currentState!.validate()) {
                  final qty = int.parse(quantityController.text);
                  setState(() {
                    _quoteItems.add(QuoteItem(name: name, price: price, quantity: qty, isMaterial: false));
                    _serviceNameController.clear();
                    _servicePriceController.clear();
                    _selectedServiceCategory = 'Todas';
                  });
                  FocusScope.of(context).unfocus();
                  Navigator.pop(context);
                }
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  void _addMaterialItem() {
    final name = _materialNameController.text.trim();
    final priceStr = _materialPriceController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el nombre del material'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final price = double.tryParse(priceStr);
    final unit = _selectedMaterialFromAutocomplete?.unidad ?? 'Unidad';

    _showMaterialQuantityDialog(name, unit, price);
  }

  void _showMaterialQuantityDialog(String name, String unidad, double? basePrice) {
    final quantityController = TextEditingController(text: '1');
    final priceController = TextEditingController(text: basePrice != null ? basePrice.toStringAsFixed(0) : '');
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        final currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double qty = double.tryParse(quantityController.text) ?? 1.0;
            double prc = double.tryParse(priceController.text) ?? 0.0;
            double total = qty * prc;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Cantidad y Precio de Material'),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text('Unidad de medida: $unidad', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    if (basePrice != null) ...[
                      const SizedBox(height: 4),
                      Text('Último precio de catálogo: ${currencyFormat.format(basePrice)}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: quantityController,
                      decoration: InputDecoration(
                        labelText: 'Cantidad ($unidad)',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      onChanged: (val) {
                        setStateDialog(() {});
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa la cantidad';
                        }
                        final q = double.tryParse(value);
                        if (q == null || q <= 0) {
                          return 'Cantidad inválida';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: priceController,
                      decoration: const InputDecoration(
                        labelText: 'Precio Unitario (\$, editable)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        setStateDialog(() {});
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa el precio unitario';
                        }
                        final p = double.tryParse(value);
                        if (p == null || p < 0) {
                          return 'Precio inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          currencyFormat.format(total),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (dialogFormKey.currentState!.validate()) {
                      final q = double.parse(quantityController.text).toInt();
                      final p = double.parse(priceController.text);
                      setState(() {
                        _quoteItems.add(QuoteItem(
                          name: name,
                          price: p,
                          quantity: q,
                          isMaterial: true,
                          unidad: unidad,
                        ));
                        _materialNameController.clear();
                        _materialPriceController.clear();
                        _selectedMaterialFromAutocomplete = null;
                      });
                      FocusScope.of(context).unfocus();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Aceptar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditMaterialDialog(int index, QuoteItem item) {
    final quantityController = TextEditingController(text: item.quantity.toString());
    final priceController = TextEditingController(text: item.price.toStringAsFixed(0));
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        final currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double qty = double.tryParse(quantityController.text) ?? 1.0;
            double prc = double.tryParse(priceController.text) ?? 0.0;
            double total = qty * prc;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Editar Material'),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (item.unidad != null) ...[
                      const SizedBox(height: 4),
                      Text('Unidad de medida: ${item.unidad}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: quantityController,
                      decoration: InputDecoration(
                        labelText: 'Cantidad${item.unidad != null ? " (${item.unidad})" : ""}',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      onChanged: (val) {
                        setStateDialog(() {});
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa la cantidad';
                        }
                        final q = double.tryParse(value);
                        if (q == null || q <= 0) {
                          return 'Cantidad inválida';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: priceController,
                      decoration: const InputDecoration(
                        labelText: 'Precio Unitario (\$, editable)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        setStateDialog(() {});
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa el precio unitario';
                        }
                        final p = double.tryParse(value);
                        if (p == null || p < 0) {
                          return 'Precio inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          currencyFormat.format(total),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (dialogFormKey.currentState!.validate()) {
                      final q = double.parse(quantityController.text).toInt();
                      final p = double.parse(priceController.text);
                      setState(() {
                        _quoteItems[index] = QuoteItem(
                          name: item.name,
                          price: p,
                          quantity: q,
                          isMaterial: true,
                          unidad: item.unidad,
                        );
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _removeServiceItem(int index) {
    setState(() {
      _quoteItems.removeAt(index);
    });
  }

  void _editServiceItem(int index) {
    final item = _quoteItems[index];
    final editNameController = TextEditingController(text: item.name);
    final editPriceController = TextEditingController(text: item.price.toStringAsFixed(0));
    final editQuantityController = TextEditingController(text: item.quantity.toString());
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Servicio'),
          content: Form(
            key: dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: editNameController,
                  decoration: const InputDecoration(labelText: 'Nombre del Servicio'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Ingresa un nombre' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: editPriceController,
                  decoration: const InputDecoration(labelText: 'Precio (\$)'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Ingresa un precio';
                    if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Precio inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: editQuantityController,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Ingresa la cantidad';
                    final qty = int.tryParse(value);
                    if (qty == null || qty <= 0) return 'Cantidad inválida';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (dialogFormKey.currentState!.validate()) {
                  setState(() {
                    _quoteItems[index] = QuoteItem(
                      name: editNameController.text.trim(),
                      price: double.parse(editPriceController.text),
                      quantity: int.parse(editQuantityController.text),
                      isMaterial: false,
                    );
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<Quote?> _saveQuoteToDb() async {
    if (_isSaving) return null;

    if (!_formKey.currentState!.validate()) {
      return null;
    }

    if (_quoteItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, agrega al menos un servicio o material al presupuesto'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }

    // Capture providers before any async/await gap
    final quotesProvider = Provider.of<QuotesProvider>(context, listen: false);
    final materialsProvider = Provider.of<MaterialsProvider>(context, listen: false);

    setState(() {
      _isSaving = true;
    });

    try {
      final newQuote = Quote(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        number: _quoteNumber,
        date: _quoteDate,
        clientName: _clientNameController.text.trim(),
        clientPhone: _clientPhoneController.text.trim(),
        clientAddress: _clientAddressController.text.trim(),
        items: List.from(_quoteItems),
        total: _totalAmount,
        status: 'Pendiente',
        observations: _observationsController.text.trim(),
      );

      // Save the quote itself using captured provider
      await quotesProvider.saveQuote(newQuote);

      // Auto-learn/update materials prices:
      final registeredMaterials = materialsProvider.materials;
      final List<MaterialItem> materialsToUpdate = [];

      for (final item in _quoteItems) {
        if (item.isMaterial) {
          // Find by name case-insensitively
          final match = registeredMaterials.firstWhere(
            (m) => m.nombre.trim().toLowerCase() == item.name.trim().toLowerCase(),
            orElse: () => MaterialItem(id: '', nombre: '', unidad: ''),
          );
          if (match.id.isNotEmpty) {
            // Update its ultimoPrecio with the price used in this quote
            materialsToUpdate.add(match.copyWith(ultimoPrecio: item.price));
          }
        }
      }
      if (materialsToUpdate.isNotEmpty) {
        await materialsProvider.saveMaterials(materialsToUpdate);
      }

      return newQuote;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar presupuesto: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _clearFields() {
    _clientNameController.clear();
    _clientPhoneController.clear();
    _clientAddressController.clear();
    _observationsController.clear();
    _serviceNameController.clear();
    _servicePriceController.clear();
    _materialNameController.clear();
    _materialPriceController.clear();
    setState(() {
      _quoteItems.clear();
      _selectedServiceCategory = 'Todas';
      _selectedMaterialFromAutocomplete = null;
    });
  }

  Future<void> _showSuccessDialog(String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 28),
              SizedBox(width: 12),
              Text('¡Guardado!', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 14),
          ),
          actions: <Widget>[
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final company = Provider.of<CompanyProvider>(context);
    final servicesProvider = Provider.of<ServicesProvider>(context);
    final materialsProvider = Provider.of<MaterialsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final accentColor = themeProvider.lightAccent;
    final frequentServices = servicesProvider.services;
    final frequentMaterials = materialsProvider.materials;
    final serviceCategories = ['Todas', ...servicesProvider.categories];
    final currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Presupuesto'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Quote metadata summary card
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "N° Presupuesto: $_quoteNumber",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      "Fecha: ${dateFormat.format(_quoteDate)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Client Card
            Text(
              "Datos del Cliente",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _clientNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Cliente *',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa el nombre del cliente';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _clientPhoneController,
                            decoration: const InputDecoration(
                              labelText: 'Teléfono',
                              prefixIcon: Icon(Icons.phone_outlined),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _clientAddressController,
                            decoration: const InputDecoration(
                              labelText: 'Dirección',
                              prefixIcon: Icon(Icons.location_on_outlined),
                              border: OutlineInputBorder(),
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Services Add Card
            Text(
              "Agregar Servicio / Concepto",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedServiceCategory,
                      decoration: const InputDecoration(
                        labelText: 'Categoría de servicios frecuentes',
                        prefixIcon: Icon(Icons.category_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: serviceCategories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedServiceCategory = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Autocomplete service name
                    Autocomplete<ServiceItem>(
                      textEditingController: _serviceNameController,
                      focusNode: _serviceNameFocusNode,
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<ServiceItem>.empty();
                        }
                        return frequentServices.where((option) {
                          final matchesCategory = _selectedServiceCategory == 'Todas' ||
                              option.category == _selectedServiceCategory;
                          final matchesName = option.name
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase());
                          return matchesCategory && matchesName;
                        });
                      },
                      displayStringForOption: (option) => option.name,
                      onSelected: (option) {
                        setState(() {
                          _serviceNameController.text = option.name;
                          _servicePriceController.text = option.price.toStringAsFixed(0);
                          _selectedServiceCategory = option.category;
                        });
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 420),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final option = options.elementAt(index);
                                  return ListTile(
                                    dense: true,
                                    title: Text(option.name),
                                    subtitle: Text(option.category),
                                    trailing: Text(currencyFormat.format(option.price)),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Buscar o escribir servicio...',
                            prefixIcon: Icon(Icons.handyman_outlined),
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.sentences,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _servicePriceController,
                            decoration: const InputDecoration(
                              labelText: 'Precio (\$)',
                              prefixIcon: Icon(Icons.attach_money),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _addServiceItem,
                          icon: const Icon(Icons.add),
                          label: const Text('Añadir'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            backgroundColor: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Materials Add Card
            Text(
              "Agregar Material",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Autocomplete material name
                    Autocomplete<MaterialItem>(
                      textEditingController: _materialNameController,
                      focusNode: _materialNameFocusNode,
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<MaterialItem>.empty();
                        }
                        return frequentMaterials.where((option) {
                          return option.nombre
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      displayStringForOption: (option) => option.nombre,
                      onSelected: (option) {
                        setState(() {
                          _materialNameController.text = option.nombre;
                          _materialPriceController.text = option.ultimoPrecio != null ? option.ultimoPrecio!.toStringAsFixed(0) : '';
                          _selectedMaterialFromAutocomplete = option;
                        });
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 420),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final option = options.elementAt(index);
                                  final hasPrice = option.ultimoPrecio != null;
                                  return ListTile(
                                    dense: true,
                                    title: Text(option.nombre),
                                    subtitle: Text('Medida: ${option.unidad}'),
                                    trailing: Text(hasPrice ? currencyFormat.format(option.ultimoPrecio) : 'Sin precio'),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Buscar o escribir material...',
                            prefixIcon: Icon(Icons.inventory_2_outlined),
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.sentences,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _materialPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Precio sugerido (\$, opcional)',
                              prefixIcon: Icon(Icons.attach_money),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _addMaterialItem,
                          icon: const Icon(Icons.add),
                          label: const Text('Añadir'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            backgroundColor: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Services Added Card
            Text(
              "Servicios Añadidos",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: _quoteItems.where((i) => !i.isMaterial).isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          "Aún no has agregado ningún servicio a este presupuesto.",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _quoteItems.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _quoteItems[index];
                            if (item.isMaterial) return const SizedBox.shrink(); // hide materials here
                            return ListTile(
                              title: Text(
                                item.name,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    "Cantidad: ${item.quantity}  •  ${currencyFormat.format(item.price)} c/u",
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Subtotal: ${currencyFormat.format(item.price * item.quantity)}",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                    onPressed: () => _editServiceItem(index),
                                    tooltip: 'Editar',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                    onPressed: () => _removeServiceItem(index),
                                    tooltip: 'Eliminar',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "SUBTOTAL SERVICIOS",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                              ),
                              Text(
                                currencyFormat.format(_servicesTotal),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),

            // Materials Added Card
            Text(
              "Materiales Añadidos",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: _quoteItems.where((i) => i.isMaterial).isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          "Aún no has agregado ningún material a este presupuesto.",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _quoteItems.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _quoteItems[index];
                            if (!item.isMaterial) return const SizedBox.shrink(); // hide services here
                            return ListTile(
                              title: Text(
                                item.name,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    "Cantidad: ${item.quantity} ${item.unidad ?? 'Unidad'}  •  ${currencyFormat.format(item.price)} c/u",
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Subtotal: ${currencyFormat.format(item.price * item.quantity)}",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                    onPressed: () => _showEditMaterialDialog(index, item),
                                    tooltip: 'Editar',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                    onPressed: () => _removeServiceItem(index),
                                    tooltip: 'Eliminar',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "SUBTOTAL MATERIALES",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                              ),
                              Text(
                                currencyFormat.format(_materialsTotal),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),

            // Total General Card
            Card(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "TOTAL GENERAL",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      currencyFormat.format(_totalAmount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Observations
            Text(
              "Observaciones (opcional)",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _observationsController,
              decoration: const InputDecoration(
                hintText: 'Ej. Forma de pago: Transferencia. Validez: 15 días. Garantía por 3 meses...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // Create Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            final navigator = Navigator.of(context);
                            final quote = await _saveQuoteToDb();
                            if (quote != null && mounted) {
                              _clearFields();
                              await _showSuccessDialog(
                                'Presupuesto N° ${quote.number} guardado en el historial con éxito.',
                              );
                              navigator.pop();
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar Historial'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            final navigator = Navigator.of(context);
                            final quote = await _saveQuoteToDb();
                            if (quote != null && mounted) {
                              // Generate PDF Bytes
                              final pdfBytes = await PdfGenerator.generateQuotePdf(
                                company: company,
                                quote: quote,
                              );
                              // Trigger Share Sheet
                              await Printing.sharePdf(
                                bytes: pdfBytes,
                                filename: 'presupuesto_${quote.number}.pdf',
                              );
                              _clearFields();
                              await _showSuccessDialog(
                                'Presupuesto N° ${quote.number} guardado y listo para compartir.',
                              );
                              navigator.pop();
                            }
                          },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Guardar y Compartir'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
