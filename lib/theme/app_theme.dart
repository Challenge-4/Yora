import 'package:flutter/material.dart';
import '../state/theme_state.dart';
import 'app_palette.dart';

class AppTheme extends InheritedNotifier<ThemeState> {
  const AppTheme({super.key, required ThemeState themeState, required super.child})
      : super(notifier: themeState);

  static ThemeState of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<AppTheme>();
    assert(widget != null, 'AppTheme.of() appelé sans AppTheme ancêtre');
    return widget!.notifier!;
  }

  static AppPalette paletteOf(BuildContext context) => of(context).palette;
}
