import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/company_provider.dart';
import '../providers/quotes_provider.dart';
import '../providers/auth_provider.dart';
import 'new_quote_screen.dart';
import 'main_screen.dart';

// 1. Premium Glowing Custom Painter for the Income Card Background
class IncomeChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.08),
          Colors.white.withOpacity(0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    // A beautiful smooth bezier curve mimicking financial growth
    path.moveTo(0, size.height * 0.75);
    path.cubicTo(
      size.width * 0.25, size.height * 0.85,
      size.width * 0.45, size.height * 0.35,
      size.width * 0.7, size.height * 0.55,
    );
    path.cubicTo(
      size.width * 0.85, size.height * 0.65,
      size.width * 0.95, size.height * 0.2,
      size.width, size.height * 0.25,
    );

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Calculate human-readable time elapsed
  String _getTimeElapsed(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 365) {
      final years = (diff.inDays / 365).floor();
      return 'Hace $years ${years == 1 ? "año" : "años"}';
    }
    if (diff.inDays >= 30) {
      final months = (diff.inDays / 30).floor();
      return 'Hace $months ${months == 1 ? "mes" : "meses"}';
    }
    if (diff.inDays > 0) {
      return 'Hace ${diff.inDays} ${diff.inDays == 1 ? "día" : "días"}';
    }
    if (diff.inHours > 0) {
      return 'Hace ${diff.inHours} ${diff.inHours == 1 ? "hora" : "horas"}';
    }
    if (diff.inMinutes > 0) {
      return 'Hace ${diff.inMinutes} ${diff.inMinutes == 1 ? "minuto" : "minutos"}';
    }
    return 'Hace unos instantes';
  }

  // Premium UI elevation wrapper helper
  Widget _buildPremiumCard({
    required Widget child,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }

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
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/images/mgz-logo.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.receipt_long_outlined,
                      color: Color(0xFF1E3A8A),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "MGZ App",
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
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
                  // 1. Business/Company Brand Header
                  Row(
                    children: [
                      if (company.logoPath != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(company.logoPath!),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildDefaultCompanyLogo(),
                          ),
                        )
                      else
                        _buildDefaultCompanyLogo(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              company.name.isNotEmpty ? company.name : "Nombre de tu Empresa",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              company.isConfigured 
                                  ? "${company.email} | ${company.phone}" 
                                  : "Configura los datos de tu empresa en la pestaña Ajustes",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                        borderRadius: BorderRadius.circular(10),
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
                                    "Configura tu logo de negocio y contacto en Ajustes para incluirlos en los presupuestos generados.",
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

                  // 2. Linear Gradient Premium Totals Card with Custom Chart Painter
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF1E3A8A), // Deep Corporate Blue
                            Color(0xFF0F172A), // Dark Midnight Blue
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Graphic growth visualization background
                          Positioned.fill(
                            child: CustomPaint(
                              painter: IncomeChartPainter(),
                            ),
                          ),
                          // Content layout
                          Padding(
                            padding: const EdgeInsets.all(22.0),
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
                                const SizedBox(height: 14),
                                Text(
                                  currencyFormat.format(totalEarnings),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "${acceptedQuotes.length} presupuestos aprobados",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Grid Statistics using Premium custom soft shadows
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          title: "Emitidos",
                          value: totalQuotesCount.toString(),
                          subtitle: "Presupuestos totales",
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
                          subtitle: "Esperando aprobación",
                          icon: Icons.hourglass_empty,
                          iconColor: const Color(0xFFF59E0B), // Orange
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),

                  // 4. Quick Actions with thin borders and soft opacity backgrounds
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
                  
                  // 5. Recent Quotes Header Section with Inline Button aligned to the right
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
                      // Elegant Right-aligned New Quote Button
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const NewQuoteScreen()),
                          );
                        },
                        icon: const Icon(Icons.add, size: 14, color: Colors.white),
                        label: const Text(
                          "Nuevo",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          backgroundColor: const Color(0xFF1E3A8A), // New sophisticated main palette color
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // 5. Visual Empty State or list with real data formatting
          if (recentQuotes.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: _buildPremiumCard(
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
                  
                  Color statusColor;
                  switch (quote.status) {
                    case 'Aceptado':
                      statusColor = const Color(0xFF16A34A); // Success Green
                      break;
                    case 'Rechazado':
                      statusColor = const Color(0xFF6B7280); // Gray for cancelled/rejected
                      break;
                    default:
                      statusColor = const Color(0xFFF59E0B); // Warning Orange
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: _buildPremiumCard(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        // Indicator dot of color
                        leading: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                quote.clientName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              currencyFormat.format(quote.total),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Presupuesto #${quote.number} (${quote.status})",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              Text(
                                _getTimeElapsed(quote.date),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
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
        color: const Color(0xFF1E3A8A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.receipt_long_outlined,
        color: Colors.white,
        size: 26,
      ),
    );
  }

  Widget _buildDefaultCompanyLogo() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
      ),
      child: const Icon(
        Icons.business_outlined,
        color: Color(0xFF475569),
        size: 28,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
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
    return _buildPremiumCard(
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
                fontSize: 24,
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
