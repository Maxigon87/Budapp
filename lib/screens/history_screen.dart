import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/quotes_provider.dart';
import '../providers/company_provider.dart';
import '../utils/pdf_generator.dart';
import 'package:printing/printing.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'Todos'; // 'Todos', 'Pendiente', 'Aceptado', 'Rechazado'
  DateTimeRange? _dateRangeFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showQuoteDetails(Quote quote) {
    final company = Provider.of<CompanyProvider>(context, listen: false);
    final quotesProvider = Provider.of<QuotesProvider>(context, listen: false);
    final currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);
    final dateFormat = DateFormat('dd/MM/yyyy');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Color statusColor;
            switch (quote.status) {
              case 'Aceptado':
                statusColor = const Color(0xFF16A34A);
                break;
              case 'Rechazado':
                statusColor = const Color(0xFFDC2626);
                break;
              default:
                statusColor = const Color(0xFFF59E0B);
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Presupuesto #${quote.number}",
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () {
                              Navigator.pop(context); // Close bottom sheet
                              _confirmDeleteQuote(quote);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Status Modifier Row
                      Row(
                        children: [
                          const Text("Estado: ", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: quote.status,
                            icon: Icon(Icons.arrow_drop_down, color: statusColor),
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                            underline: Container(
                              height: 2,
                              color: statusColor,
                            ),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                quotesProvider.updateQuoteStatus(quote.id, newValue);
                                setModalState(() {
                                  // Update state in modal
                                  // Since quote reference is final, we re-fetch quote data or just redraw
                                });
                                setState(() {
                                  // Refresh parent screen too
                                });
                                Navigator.pop(context); // Close and reopen to update full details safely
                                _showQuoteDetails(quotesProvider.quotes.firstWhere((q) => q.id == quote.id));
                              }
                            },
                            items: <String>['Pendiente', 'Aceptado', 'Rechazado']
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      const Divider(height: 32),

                      // Date & Client Details
                      Text("INFORMACIÓN DEL CLIENTE", style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text("Nombre: ${quote.clientName}", style: const TextStyle(fontSize: 15)),
                      if (quote.clientPhone.isNotEmpty)
                        Text("Teléfono: ${quote.clientPhone}", style: const TextStyle(fontSize: 15)),
                      if (quote.clientAddress.isNotEmpty)
                        Text("Dirección: ${quote.clientAddress}", style: const TextStyle(fontSize: 15)),
                      Text("Fecha: ${dateFormat.format(quote.date)}", style: const TextStyle(fontSize: 15)),
                      
                      const Divider(height: 32),

                      // Services Table
                      Text("DETALLE DE SERVICIOS", style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Table(
                        border: TableBorder(
                          horizontalInside: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
                        ),
                        columnWidths: const {
                          0: FlexColumnWidth(3),
                          1: FlexColumnWidth(1),
                        },
                        children: [
                          ...quote.items.map((item) {
                            return TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(item.name),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      currencyFormat.format(item.price),
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "Total: ${currencyFormat.format(quote.total)}",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),

                      if (quote.observations.isNotEmpty) ...[
                        const Divider(height: 32),
                        Text("OBSERVACIONES", style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(quote.observations, style: const TextStyle(fontStyle: FontStyle.italic)),
                      ],

                      const Divider(height: 32),

                      // PDF Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final pdfBytes = await PdfGenerator.generateQuotePdf(company: company, quote: quote);
                                await Printing.layoutPdf(
                                  onLayout: (format) => pdfBytes,
                                  name: 'presupuesto_${quote.number}',
                                );
                              },
                              icon: const Icon(Icons.print),
                              label: const Text("Imprimir / Guardar"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () async {
                                final pdfBytes = await PdfGenerator.generateQuotePdf(company: company, quote: quote);
                                await Printing.sharePdf(
                                  bytes: pdfBytes,
                                  filename: 'presupuesto_${quote.number}.pdf',
                                );
                              },
                              icon: const Icon(Icons.share),
                              label: const Text("Compartir"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _confirmDeleteQuote(Quote quote) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('¿Eliminar presupuesto?'),
          content: Text('¿Estás seguro de que deseas eliminar el presupuesto N° ${quote.number} de ${quote.clientName}? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Provider.of<QuotesProvider>(context, listen: false).deleteQuote(quote.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Presupuesto eliminado'),
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

  void _selectDateRange() async {
    final initialDateRange = _dateRangeFilter ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 30)),
          end: DateTime.now(),
        );

    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: initialDateRange,
      locale: const Locale('es', 'ES'),
      confirmText: 'Filtrar',
      cancelText: 'Limpiar',
    );

    if (pickedRange != null) {
      setState(() {
        _dateRangeFilter = pickedRange;
      });
    } else {
      // DateRangePicker cancel yields null, but we want to allow clearing.
      // If they click cancel/back we keep existing. If they select no range, we can clear in a separate button.
    }
  }

  @override
  Widget build(BuildContext context) {
    final quotesProvider = Provider.of<QuotesProvider>(context);
    final currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);

    // Apply Search and Filters
    final filteredQuotes = quotesProvider.quotes.where((quote) {
      // 1. Client Search filter
      final matchesQuery = quote.clientName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          quote.number.contains(_searchQuery);

      // 2. Status filter
      final matchesStatus = _statusFilter == 'Todos' || quote.status == _statusFilter;

      // 3. Date Range filter
      bool matchesDate = true;
      if (_dateRangeFilter != null) {
        // Start date starts at 00:00:00
        final start = DateTime(_dateRangeFilter!.start.year, _dateRangeFilter!.start.month, _dateRangeFilter!.start.day);
        // End date ends at 23:59:59
        final end = DateTime(_dateRangeFilter!.end.year, _dateRangeFilter!.end.month, _dateRangeFilter!.end.day, 23, 59, 59);
        matchesDate = quote.date.isAfter(start) && quote.date.isBefore(end);
      }

      return matchesQuery && matchesStatus && matchesDate;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
      ),
      body: Column(
        children: [
          // Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                // Client/Number Search field
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cliente o N°...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Status Filter Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusFilter,
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _statusFilter = newValue;
                          });
                        }
                      },
                      items: <String>['Todos', 'Pendiente', 'Aceptado', 'Rechazado']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Date Filter Badge Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                InputChip(
                  label: Text(
                    _dateRangeFilter == null
                        ? 'Cualquier fecha'
                        : '${DateFormat('dd/MM').format(_dateRangeFilter!.start)} - ${DateFormat('dd/MM').format(_dateRangeFilter!.end)}',
                  ),
                  avatar: _dateRangeFilter == null
                      ? const Icon(Icons.calendar_month, size: 16)
                      : null,
                  onPressed: _selectDateRange,
                  onDeleted: _dateRangeFilter != null
                      ? () {
                          setState(() {
                            _dateRangeFilter = null;
                          });
                        }
                      : null,
                ),
                const SizedBox(width: 8),
                if (_searchQuery.isNotEmpty || _statusFilter != 'Todos' || _dateRangeFilter != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                        _statusFilter = 'Todos';
                        _dateRangeFilter = null;
                      });
                    },
                    child: const Text('Limpiar filtros'),
                  ),
              ],
            ),
          ),
          
          const Divider(),

          // History List
          Expanded(
            child: filteredQuotes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No se encontraron presupuestos',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Intenta modificar tus filtros de búsqueda',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredQuotes.length,
                    itemBuilder: (context, index) {
                      final quote = filteredQuotes[index];
                      final dateFormat = DateFormat('dd/MM/yyyy');
                      
                      Color statusColor;
                      switch (quote.status) {
                        case 'Aceptado':
                          statusColor = const Color(0xFF16A34A);
                          break;
                        case 'Rechazado':
                          statusColor = const Color(0xFFDC2626);
                          break;
                        default:
                          statusColor = const Color(0xFFF59E0B);
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          onTap: () => _showQuoteDetails(quote),
                          title: Row(
                            children: [
                              Text(
                                "N° ${quote.number}",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: statusColor.withOpacity(0.4)),
                                ),
                                child: Text(
                                  quote.status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            "${quote.clientName} • ${dateFormat.format(quote.date)}",
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currencyFormat.format(quote.total),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
