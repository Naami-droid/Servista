import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('is_dark_theme') ?? false;
      themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    } catch (e) {
      print("ThemeManager initialization failed: $e");
    }
  }

  Future<void> toggleTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = themeModeNotifier.value;
      final next = current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
      themeModeNotifier.value = next;
      await prefs.setBool('is_dark_theme', next == ThemeMode.dark);
    } catch (e) {
      print("Error toggling theme: $e");
    }
  }

  bool get isDark => themeModeNotifier.value == ThemeMode.dark;
}
