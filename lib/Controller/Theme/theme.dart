import 'package:flutter/cupertino.dart';

class ThemeProvider extends ChangeNotifier {
  bool _followSystemTheme = true;
  bool _isDarkMode = false;

  bool get followSystemTheme => _followSystemTheme;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _initializeSystemTheme();
  }

  void _initializeSystemTheme() {
    final brightness = WidgetsBinding.instance.window.platformBrightness;
    _isDarkMode = brightness == Brightness.dark;
    notifyListeners();
  }

  void updateSystemTheme(bool isDark) {
    if (_followSystemTheme && _isDarkMode != isDark) {
      _isDarkMode = isDark;
      notifyListeners();
    }
  }

  void setFollowSystemTheme(bool follow) {
    _followSystemTheme = follow;
    notifyListeners();
  }

  void setDarkMode(bool isDark) {
    _isDarkMode = isDark;
    notifyListeners();
  }
}
