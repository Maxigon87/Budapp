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
import '../providers/theme_provider.dart';

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

  Widget _buildSidebarTile({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final theme = Theme.of(context);
    final isSelected = _selectedIndex == index;
    final accentColor = Provider.of<ThemeProvider>(context).lightAccent;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? accentColor.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        onTap: () => setSelectedIndex(index),
        leading: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected ? accentColor : theme.colorScheme.onSurface.withOpacity(0.7),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? accentColor : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        dense: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final accentColor = themeProvider.lightAccent;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 800;

    if (isWideScreen) {
      return Scaffold(
        body: Row(
          children: [
            // Sidebar Navigation
            Container(
              width: 260,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // App branding header
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/budapp-logo.png',
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.receipt_long_outlined,
                              color: Color(0xFF1E3A8A),
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Budapp",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  
                  // Navigation Items
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _buildSidebarTile(
                          index: 0,
                          icon: Icons.dashboard_outlined,
                          selectedIcon: Icons.dashboard,
                          label: "Inicio",
                        ),
                        _buildSidebarTile(
                          index: 1,
                          icon: Icons.history_outlined,
                          selectedIcon: Icons.history,
                          label: "Historial",
                        ),
                        _buildSidebarTile(
                          index: 2,
                          icon: Icons.handyman_outlined,
                          selectedIcon: Icons.handyman,
                          label: "Servicios",
                        ),
                        _buildSidebarTile(
                          index: 3,
                          icon: Icons.settings_outlined,
                          selectedIcon: Icons.settings,
                          label: "Configuración",
                        ),
                        
                        // New Quote Button directly in the sidebar
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const NewQuoteScreen()),
                            ).then((_) {
                              setState(() {});
                            });
                          },
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text(
                            'Nuevo Presupuesto',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: accentColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // User info & Logout at bottom
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        if (!auth.isAuthenticated) {
                          return Text(
                            "Modo Local Offline",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Nube Conectada",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              auth.user?.email ?? "",
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await auth.signOut();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Sesión cerrada')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.logout, size: 14),
                              label: const Text("Cerrar Sesión", style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                minimumSize: Size.zero,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            // Main content area
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(
                  key: ValueKey(_selectedIndex),
                  child: _screens[_selectedIndex],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _screens[_selectedIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.handyman_outlined),
            selectedIcon: Icon(Icons.handyman),
            label: 'Servicios',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Configuración',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0 || _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NewQuoteScreen()),
                ).then((_) {
                  setState(() {});
                });
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Nuevo Presupuesto',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              backgroundColor: accentColor,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            )
          : null,
    );
  }
}
