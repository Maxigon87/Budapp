import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/quotes_provider.dart';
import '../providers/services_provider.dart';
import '../providers/company_provider.dart';
import '../utils/pdf_generator.dart';
import 'package:printing/printing.dart';

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
    super.dispose();
  }

  double get _totalAmount {
    return _quoteItems.fold(0.0, (sum, item) => sum + item.price);
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

    setState(() {
      _quoteItems.add(QuoteItem(name: name, price: price));
      _serviceNameController.clear();
      _servicePriceController.clear();
    });
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
    if (!_formKey.currentState!.validate()) {
      return null;
    }

    if (_quoteItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, agrega al menos un servicio al presupuesto'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }

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

    await Provider.of<QuotesProvider>(context, listen: false).saveQuote(newQuote);
    return newQuote;
  }

  @override
  Widget build(BuildContext context) {
    final company = Provider.of<CompanyProvider>(context);
    final frequentServices = Provider.of<ServicesProvider>(context).services;
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
                    // Autocomplete service name
                    Autocomplete<ServiceItem>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<ServiceItem>.empty();
                        }
                        return frequentServices.where((option) {
                          return option.name
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      displayStringForOption: (option) => option.name,
                      onSelected: (option) {
                        _serviceNameController.text = option.name;
                        _servicePriceController.text = option.price.toStringAsFixed(0);
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        // Link our custom controller to autocomplete
                        // If user types, we keep it in sync
                        textEditingController.addListener(() {
                          _serviceNameController.text = textEditingController.text;
                        });
                        
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
                            backgroundColor: const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Services Table Card
            Text(
              "Servicios Añadidos",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: _quoteItems.isEmpty
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
                            return ListTile(
                              title: Text(item.name, style: const TextStyle(fontSize: 14)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    currencyFormat.format(item.price),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    onPressed: () => _editServiceItem(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    onPressed: () => _removeServiceItem(index),
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
                                "TOTAL",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                currencyFormat.format(_totalAmount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
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
                    onPressed: () async {
                      final quote = await _saveQuoteToDb();
                      if (quote != null && mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Presupuesto guardado en el historial'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Guardar Historial'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
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
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Presupuesto guardado y compartido'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Guardar y Compartir'),
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
