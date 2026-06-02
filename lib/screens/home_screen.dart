import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/company_provider.dart';
import '../providers/quotes_provider.dart';
import '../providers/auth_provider.dart';
import 'new_quote_screen.dart';
import 'main_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final company = Provider.of<CompanyProvider>(context);
    final quotesProvider = Provider.of<QuotesProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    final allQuotes = quotesProvider.quotes;
    final recentQuotes = allQuotes.take(5).toList();

    // Statistics calculations
    final totalQuotesCount = allQuotes.length;
    final acceptedQuotes = allQuotes.where((q) => q.status == 'Aceptado').toList();
    final pendingQuotes = allQuotes.where((q) => q.status == 'Pendiente').toList();
    
    double totalEarnings = 0;
    for (var q in acceptedQuotes) {
      totalEarnings += q.total;
    }

    final currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Elegant corporate app bar with minimal cloud sync status
          SliverAppBar(
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFFF8FAFC),
            surfaceTintColor: Colors.transparent,
            title: const Text(
              "MGZ",
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
            ),
            actions: [
              // Cloud Sync Status Indicator
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Tooltip(
                  message: authProvider.isAuthenticated
                      ? "Conectado como ${authProvider.user?.email}"
                      : "Modo Local (Configura Firebase en Ajustes)",
                  child: TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            authProvider.isAuthenticated
                                ? "Sincronización activa con ${authProvider.user?.email}"
                                : "Trabajando en almacenamiento local. Configura la nube en Ajustes.",
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: Icon(
                      authProvider.isAuthenticated ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                      size: 16,
                      color: authProvider.isAuthenticated ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
                    ),
                    label: Text(
                      authProvider.isAuthenticated ? "Nube" : "Local",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: authProvider.isAuthenticated ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: authProvider.isAuthenticated
                          ? const Color(0xFF16A34A).withOpacity(0.08)
                          : const Color(0xFFF59E0B).withOpacity(0.08),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Business Stats & Header Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Strong Brand Header
                  Row(
                    children: [
                      if (company.logoPath != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(company.logoPath!),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildDefaultLogo(),
                          ),
                        )
                      else
                        _buildDefaultLogo(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "MGZ",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              company.name.isNotEmpty ? company.name : "Generador de Presupuestos",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Crea, administra y comparte presupuestos profesionales.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFE2E8F0), height: 1),
                  const SizedBox(height: 20),

                  // Missing Company Profile Banner
                  if (!company.isConfigured)
                    Card(
                      color: const Color(0xFFFEF2F2),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFFFCA5A5), width: 1),
                      ),
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Faltan Datos de la Empresa",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF991B1B),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    "Configura tu logo y datos de contacto en Ajustes para incluirlos en los presupuestos generados.",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF7F1D1D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 2. Main Attention-Grabbing Gradient Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF2563EB), // Blue 600
                            Color(0xFF1D4ED8), // Blue 700
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "💰 Ingresos Totales",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Icon(Icons.trending_up, color: Colors.white.withOpacity(0.9), size: 20),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            currencyFormat.format(totalEarnings),
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "$totalQuotesCount presupuestos emitidos, ${acceptedQuotes.length} aprobados",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Mini Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          title: "Presupuestos",
                          value: totalQuotesCount.toString(),
                          subtitle: "Emitidos en total",
                          icon: Icons.description_outlined,
                          iconColor: const Color(0xFF2563EB), // Blue
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          title: "Pendientes",
                          value: pendingQuotes.length.toString(),
                          subtitle: "Esperando respuesta",
                          icon: Icons.hourglass_empty,
                          iconColor: const Color(0xFFF59E0B), // Orange
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),

                  // 4. Quick Actions
                  const Text(
                    "⚡ Acciones Rápidas",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionButton(
                          context,
                          label: "Nuevo",
                          icon: Icons.add_circle_outline,
                          iconColor: const Color(0xFF2563EB),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const NewQuoteScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickActionButton(
                          context,
                          label: "Historial",
                          icon: Icons.history,
                          iconColor: const Color(0xFFF59E0B),
                          onTap: () {
                            final mainState = context.findAncestorStateOfType<MainScreenState>();
                            if (mainState != null) {
                              mainState.setSelectedIndex(1);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickActionButton(
                          context,
                          label: "Servicios",
                          icon: Icons.handyman_outlined,
                          iconColor: const Color(0xFF16A34A),
                          onTap: () {
                            final mainState = context.findAncestorStateOfType<MainScreenState>();
                            if (mainState != null) {
                              mainState.setSelectedIndex(2);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickActionButton(
                          context,
                          label: "Ajustes",
                          icon: Icons.settings_outlined,
                          iconColor: const Color(0xFF6B7280),
                          onTap: () {
                            final mainState = context.findAncestorStateOfType<MainScreenState>();
                            if (mainState != null) {
                              mainState.setSelectedIndex(3);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 28),
                  
                  // Recent Quotes Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Presupuestos Recientes",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (allQuotes.length > 5)
                        const Text(
                          "Pestaña Historial para ver todos",
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // 5. Redesigned Visual Empty State
          if (recentQuotes.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Sin presupuestos todavía",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Crea tu primer presupuesto para comenzar.",
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const NewQuoteScreen()),
                            );
                          },
                          child: const Text("Crear Presupuesto"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final quote = recentQuotes[index];
                  final dateFormat = DateFormat('dd/MM/yyyy');
                  
                  Color statusColor;
                  IconData statusIcon;
                  switch (quote.status) {
                    case 'Aceptado':
                      statusColor = const Color(0xFF16A34A); // Success Green
                      statusIcon = Icons.check_circle_outline;
                      break;
                    case 'Rechazado':
                      statusColor = const Color(0xFFDC2626); // Error Red
                      statusIcon = Icons.cancel_outlined;
                      break;
                    default:
                      statusColor = const Color(0xFFF59E0B); // Warning Orange
                      statusIcon = Icons.hourglass_empty;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.08),
                          child: Icon(statusIcon, color: statusColor, size: 20),
                        ),
                        title: Row(
                          children: [
                            Text(
                              "Presupuesto #${quote.number}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827), fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
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
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                quote.clientName,
                                style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF4B5563), fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dateFormat.format(quote.date),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                              ),
                            ],
                          ),
                        ),
                        trailing: Text(
                          currencyFormat.format(quote.total),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: recentQuotes.length,
              ),
            ),
          
          // Extra bottom padding for floating action button
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          )
        ],
      ),
    );
  }

  Widget _buildDefaultLogo() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.receipt_long_outlined,
        color: Colors.white,
        size: 26,
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(icon, color: iconColor, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
