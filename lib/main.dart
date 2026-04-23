import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:result_wave/providers/theme_provider.dart';
import 'package:result_wave/screens/splash_screen.dart';
import 'package:result_wave/services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService().initializeDatabase();
  runApp(
    ChangeNotifierProvider(create: (_) => ThemeProvider(), child: MyApp()),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'ResultWave',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF2563EB),
              secondary: Color(0xFF7C3AED),
              surface: Colors.white,
              background: Color(0xFFF8FAFC),
            ),
            useMaterial3: true,
            appBarTheme: AppBarTheme(
              elevation: 0,
              centerTitle: true,
              backgroundColor: Colors.transparent,
              foregroundColor: Color(0xFF1E293B),
            ),
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.dark(
              primary: Color(0xFF3B82F6),
              secondary: Color(0xFF8B5CF6),
              surface: Color(0xFF1E293B),
              background: Color(0xFF0F172A),
            ),
            useMaterial3: true,
            appBarTheme: AppBarTheme(
              elevation: 0,
              centerTitle: true,
              backgroundColor: Colors.transparent,
            ),
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          themeMode: themeProvider.themeMode,
          home: SplashScreen(),
        );
      },
    );
  }
}
