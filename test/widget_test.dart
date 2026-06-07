// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:budapp/main.dart';
import 'package:budapp/providers/company_provider.dart';
import 'package:budapp/providers/services_provider.dart';
import 'package:budapp/providers/quotes_provider.dart';
import 'package:budapp/providers/auth_provider.dart';
import 'package:budapp/providers/theme_provider.dart';

void main() {
  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
    await Hive.openBox('company_settings');
    await Hive.openBox('services');
    await Hive.openBox('quotes');
    await Hive.openBox('theme_settings');
  });

  tearDown(() async {
    await Hive.close();
  });

  testWidgets('App load smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CompanyProvider()),
          ChangeNotifierProvider(create: (_) => ServicesProvider()),
          ChangeNotifierProvider(create: (_) => QuotesProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify that the App widget is successfully rendered.
    expect(find.byType(MyApp), findsOneWidget);
  });
}
