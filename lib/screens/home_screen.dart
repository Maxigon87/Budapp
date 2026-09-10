import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/company_provider.dart';
import '../providers/quotes_provider.dart';
import '../providers/auth_provider.dart';
import 'new_quote_screen.dart';
import 'main_screen.dart';
import '../utils/pdf_generator.dart';
import 'package:printing/printing.dart';

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
    const pageBackground = Color(0xFF0F131C);
    const surfaceColor = Color(0xFF1C1F29);
    const surfaceHighColor = Color(0xFF262A34);
    const primaryColor = Color(0xFF3B82F6);
    const secondaryColor = Color(0xFF4EDEA3);
    const tertiaryColor = Color(0xFFFFB95F);
    const textPrimary = Color(0xFFDFE2EF);
    const textSecondary = Color(0xFFC2C6D6);

    return Scaffold(
      backgroundColor: pageBackground,
      body: CustomScrollView(
        slivers: [
          // Stitch Header: App title + EMGI badge + Cloud sync indicator
          SliverAppBar(
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xEC0A0E17),
            surfaceTintColor: Colors.transparent,
            title: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF002E6A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.precision_manufacturing_outlined,
                    color: Color(0xFFADC6FF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          "Budapp",
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: surfaceHighColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "EMGI",
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: authProvider.isAuthenticated ? secondaryColor : tertiaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          authProvider.isAuthenticated
                              ? "Nube activa • Sincronizado"
                              : "Modo Local • Sin sesión",
                          style: const TextStyle(
                            fontSize: 10,
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () {
                  final mainState = context.findAncestorStateOfType<MainScreenState>();
                  if (mainState != null) {
                    mainState.setSelectedIndex(3);
                  }
                },
                icon: const Icon(Icons.person_outline, color: textSecondary, size: 22),
                tooltip: 'Perfil',
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
                  // 1. Workshop Profile Snapshot Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: surfaceHighColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: company.logoPath != null
                                      ? Image.file(
                                          File(company.logoPath!),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, e, s) => const Icon(
                                            Icons.memory_outlined,
                                            color: primaryColor,
                                            size: 24,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.memory_outlined,
                                          color: primaryColor,
                                          size: 24,
                                        ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: secondaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: pageBackground, width: 1.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    company.name.isNotEmpty ? company.name : "EMGI TEC",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: surfaceColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      "PRO",
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                company.isConfigured
                                    ? "${company.email} • ${company.phone}"
                                    : "Sin configurar • Toca Ajustes",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0x3300A572),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: secondaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              "ONLINE",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Missing Company Profile Banner
                  if (!company.isConfigured)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0x3393000A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF93000A), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB4AB), size: 22),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Faltan Datos de la Empresa",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFFB4AB),
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Configura tus datos de contacto en Ajustes para incluirlos en presupuestos.",
                                  style: TextStyle(fontSize: 11, color: Color(0xFFFFDAD6)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 2. Hero Income Card (Stitch Minimalist OLED Card)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: surfaceHighColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF31353F), width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        // Ambient top-left illumination glow
                        Positioned(
                          top: -30,
                          left: -30,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primaryColor.withOpacity(0.12),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: IncomeChartPainter(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.monetization_on_outlined, color: tertiaryColor, size: 18),
                                      SizedBox(width: 6),
                                      Text(
                                        "INGRESOS TOTALES",
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0x3300A572),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.trending_up, color: secondaryColor, size: 13),
                                        SizedBox(width: 3),
                                        Text(
                                          "+100%",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: secondaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    currencyFormat.format(totalEarnings),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    "ARS",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.verified, color: secondaryColor, size: 14),
                                  const SizedBox(width: 5),
                                  Text(
                                    "${acceptedQuotes.length} presupuestos aprobados",
                                    style: const TextStyle(
                                      color: textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Counter Grid (2 Columns: Emitidos, Pendientes)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF262A34), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Emitidos",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: surfaceHighColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.description_outlined, color: primaryColor, size: 16),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                totalQuotesCount.toString(),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                "Presupuestos totales",
                                style: TextStyle(fontSize: 11, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF262A34), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Pendientes",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: surfaceHighColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.hourglass_empty, color: tertiaryColor, size: 16),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                pendingQuotes.length.toString(),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                "Esperando aprobación",
                                style: TextStyle(fontSize: 11, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 4. Quick Actions Panel (4 Columns)
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: tertiaryColor, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        "ACCIONES RÁPIDAS",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textSecondary,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStitchQuickTile(
                          context,
                          label: "Nuevo",
                          icon: Icons.add_circle_outline,
                          iconBgColor: primaryColor.withOpacity(0.18),
                          iconColor: primaryColor,
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
                        child: _buildStitchQuickTile(
                          context,
                          label: "Historial",
                          icon: Icons.history,
                          iconBgColor: tertiaryColor.withOpacity(0.18),
                          iconColor: tertiaryColor,
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
                        child: _buildStitchQuickTile(
                          context,
                          label: "Servicios",
                          icon: Icons.home_repair_service_outlined,
                          iconBgColor: secondaryColor.withOpacity(0.18),
                          iconColor: secondaryColor,
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
                        child: _buildStitchQuickTile(
                          context,
                          label: "Ajustes",
                          icon: Icons.settings_outlined,
                          iconBgColor: surfaceHighColor,
                          iconColor: textSecondary,
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
                  const SizedBox(height: 24),

                  // 5. Recent Quotes Header Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "Presupuestos Recientes",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: surfaceHighColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              recentQuotes.length.toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const NewQuoteScreen()),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF002E6A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add, size: 14, color: Color(0xFFADC6FF)),
                              SizedBox(width: 4),
                              Text(
                                "Nuevo",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFADC6FF)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // Recent Quotes List
          if (recentQuotes.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF262A34), width: 1),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.receipt_long_outlined,
                        size: 40,
                        color: primaryColor,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Sin presupuestos todavía",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Crea tu primer presupuesto para comenzar.",
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const NewQuoteScreen()),
                          );
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text("Crear Presupuesto"),
                      ),
                    ],
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
                      statusColor = secondaryColor;
                      break;
                    case 'Rechazado':
                      statusColor = const Color(0xFF8C909F);
                      break;
                    default:
                      statusColor = tertiaryColor;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF262A34), width: 1),
                      ),
                      child: ListTile(
                        onTap: () => _showQuoteDetails(context, quote),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                                  color: textPrimary,
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
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "Presupuesto #${quote.number}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
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
                              Text(
                                _getTimeElapsed(quote.date),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: textSecondary,
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
          
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          )
        ],
      ),
    );
  }

  Widget _buildStitchQuickTile(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1F29),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF262A34), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFDFE2EF),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _showQuoteDetails(BuildContext context, Quote quote) {
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
                              _confirmDeleteQuote(context, quote);
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
                                Navigator.pop(context); // Close and reopen to update full details safely
                                final updatedQuote = quotesProvider.quotes.firstWhere((q) => q.id == quote.id);
                                _showQuoteDetails(context, updatedQuote);
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

  void _confirmDeleteQuote(BuildContext context, Quote quote) {
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
}
