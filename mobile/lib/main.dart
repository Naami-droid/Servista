import 'package:flutter/material.dart';
import 'features/auth/auth_screen.dart';
import 'data/services/offline_sync_service.dart';
import 'data/services/theme_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  OfflineSyncService().init();
  await ThemeManager().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager().themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Servista',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1a56db),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.grey[50],
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(
                color: Color(0xFF1a56db),
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1a56db),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.grey[900],
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black12,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
          home: const AuthScreen(),
        );
      },
    );
  }
}
