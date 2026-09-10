import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'services_screen.dart';
import 'settings_screen.dart';
import 'new_quote_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/company_provider.dart';
import '../providers/services_provider.dart';
import '../providers/quotes_provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  AuthProvider? _authProvider;
  String? _lastUserId;

  final List<Widget> _screens = [
    const HomeScreen(),
    const HistoryScreen(),
    const ServicesScreen(),
    const SettingsScreen(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context);
    if (_authProvider != authProvider) {
      _authProvider?.removeListener(_onAuthStateChanged);
      _authProvider = authProvider;
      _authProvider?.addListener(_onAuthStateChanged);
      // Run immediately in case user is already authenticated
      _onAuthStateChanged();
    }
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    final auth = _authProvider;
    if (auth != null) {
      final currentUid = auth.user?.uid;
      if (auth.isAuthenticated) {
        if (_lastUserId != currentUid) {
          _lastUserId = currentUid;
          _autoSyncFromCloud();
        }
      } else {
        _lastUserId = null;
      }
    }
  }

  void _autoSyncFromCloud() async {
    try {
      final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
      final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
      final quotesProvider = Provider.of<QuotesProvider>(context, listen: false);

      await Future.wait([
        companyProvider.syncFromCloud(),
        servicesProvider.syncFromCloud(),
        quotesProvider.syncFromCloud(),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datos sincronizados con la nube'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error in automatic startup sync: $e");
    }
  }

  void setSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: const Color(0xFF0F131C),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _screens[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xDA0F131C),
          border: Border(
            top: BorderSide(color: Color(0xFF1C1F29), width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          backgroundColor: Colors.transparent,
          indicatorColor: primaryColor.withOpacity(0.2),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: primaryColor),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long, color: primaryColor),
              label: 'Historial',
            ),
            NavigationDestination(
              icon: Icon(Icons.build_outlined),
              selectedIcon: Icon(Icons.build, color: primaryColor),
              label: 'Servicios',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune, color: primaryColor),
              label: 'Ajustes',
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedIndex == 0 || _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NewQuoteScreen()),
                );
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Nuevo Presupuesto',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
              ),
              backgroundColor: primaryColor,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            )
          : null,
    );
  }
}
