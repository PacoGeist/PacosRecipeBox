import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-adjustable appearance settings, persisted with SharedPreferences.
class AppSettings extends ChangeNotifier {
  static const fonts = <String, String>{
    'Nunito': 'Nunito (friendly)',
    'Lora': 'Lora (classic serif)',
    'PlayfairDisplay': 'Playfair (elegant)',
    'AtkinsonHyperlegible': 'Atkinson (easy to read)',
    'Caveat': 'Caveat (handwritten)',
  };

  late SharedPreferences _p;

  ThemeMode themeMode = ThemeMode.system;
  double recipeFontScale = 1.0; // applies to recipe text (ingredients, steps)
  double appFontScale = 1.0; // applies to everything
  String fontFamily = 'Nunito';
  Color? backgroundColor;
  Color? foregroundColor; // cards / panels
  Color? borderColor;
  Color? textColor;
  Color? accentColor;
  bool showSplash = true;
  String webImportProxy = ''; // web app only: CORS helper for importing recipes
  bool keepScreenOn = false;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[_p.getInt('themeMode') ?? 0];
    recipeFontScale = _p.getDouble('recipeFontScale') ?? 1.0;
    appFontScale = _p.getDouble('appFontScale') ?? 1.0;
    fontFamily = _p.getString('fontFamily') ?? 'Nunito';
    if (!fonts.containsKey(fontFamily)) fontFamily = 'Nunito';
    backgroundColor = _color('bg');
    foregroundColor = _color('fg');
    borderColor = _color('border');
    textColor = _color('text');
    accentColor = _color('accent');
    showSplash = _p.getBool('showSplash') ?? true;
    webImportProxy = _p.getString('webImportProxy') ?? '';
  }

  Color? _color(String k) {
    final v = _p.getInt('color_$k');
    return v == null ? null : Color(v);
  }

  Future<void> _setColor(String k, Color? c) async {
    if (c == null) {
      await _p.remove('color_$k');
    } else {
      await _p.setInt('color_$k', c.toARGB32());
    }
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    await _p.setInt('themeMode', m.index);
    notifyListeners();
  }

  Future<void> setRecipeFontScale(double v) async {
    recipeFontScale = v;
    await _p.setDouble('recipeFontScale', v);
    notifyListeners();
  }

  Future<void> setAppFontScale(double v) async {
    appFontScale = v;
    await _p.setDouble('appFontScale', v);
    notifyListeners();
  }

  Future<void> setFontFamily(String f) async {
    fontFamily = f;
    await _p.setString('fontFamily', f);
    notifyListeners();
  }

  Future<void> setShowSplash(bool v) async {
    showSplash = v;
    await _p.setBool('showSplash', v);
    notifyListeners();
  }

  Future<void> setWebImportProxy(String v) async {
    webImportProxy = v.trim();
    await _p.setString('webImportProxy', webImportProxy);
    notifyListeners();
  }

  Future<void> setColor(String which, Color? c) async {
    switch (which) {
      case 'bg':
        backgroundColor = c;
      case 'fg':
        foregroundColor = c;
      case 'border':
        borderColor = c;
      case 'text':
        textColor = c;
      case 'accent':
        accentColor = c;
    }
    await _setColor(which, c);
    notifyListeners();
  }

  Future<void> resetColors() async {
    for (final k in ['bg', 'fg', 'border', 'text', 'accent']) {
      await setColor(k, null);
    }
  }
}
