import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AppThemeColor {
  final String name;
  final Color lightColor;
  final Color darkColor;

  const AppThemeColor({
    required this.name,
    required this.lightColor,
    required this.darkColor,
  });
}

class ThemeProvider extends ChangeNotifier {
  final Box _box = Hive.box('theme_settings');

  static const List<AppThemeColor> themeColors = [
    AppThemeColor(
      name: 'Azul',
      lightColor: Color(0xFF3B82F6),
      darkColor: Color(0xFF1D4ED8),
    ),
    AppThemeColor(
      name: 'Verde',
      lightColor: Color(0xFF10B981),
      darkColor: Color(0xFF047857),
    ),
    AppThemeColor(
      name: 'Naranja',
      lightColor: Color(0xFFF97316),
      darkColor: Color(0xFFC2410C),
    ),
    AppThemeColor(
      name: 'Púrpura',
      lightColor: Color(0xFF8B5CF6),
      darkColor: Color(0xFF6D28D9),
    ),
    AppThemeColor(
      name: 'Rosa',
      lightColor: Color(0xFFEC4899),
      darkColor: Color(0xFFBE185D),
    ),
    AppThemeColor(
      name: 'Teal',
      lightColor: Color(0xFF14B8A6),
      darkColor: Color(0xFF0F766E),
    ),
    AppThemeColor(
      name: 'Amarillo',
      lightColor: Color(0xFFFBBF24),
      darkColor: Color(0xFFD97706),
    ),
  ];

  int get colorIndex => _box.get('colorIndex', defaultValue: 0) as int;

  AppThemeColor get currentThemeColor {
    final index = colorIndex;
    if (index >= 0 && index < themeColors.length) {
      return themeColors[index];
    }
    return themeColors[0];
  }

  Color get lightAccent => currentThemeColor.lightColor;
  Color get darkAccent => currentThemeColor.darkColor;

  Future<void> setColorIndex(int index) async {
    if (index >= 0 && index < themeColors.length) {
      await _box.put('colorIndex', index);
      notifyListeners();
    }
  }
}
