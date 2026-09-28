import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di/repository_providers.dart';
import '../local_storage/local_storage.dart';
import 'app_colors.dart';

/// Theme mode + brand flavour, persisted across launches.
class ThemeSettings {
  const ThemeSettings({
    this.mode = ThemeMode.light,
    this.flavor = AppThemeFlavor.green,
  });

  final ThemeMode mode;
  final AppThemeFlavor flavor;

  ThemeSettings copyWith({ThemeMode? mode, AppThemeFlavor? flavor}) =>
      ThemeSettings(mode: mode ?? this.mode, flavor: flavor ?? this.flavor);
}

class ThemeController extends Notifier<ThemeSettings> {
  late final LocalStorage _storage = ref.read(localStorageProvider);

  @override
  ThemeSettings build() {
    return ThemeSettings(
      mode: _modeFromName(_storage.getString(StorageKeys.themeMode)),
      flavor: AppThemeFlavor.fromName(_storage.getString(StorageKeys.themeFlavor)),
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    await _storage.setString(StorageKeys.themeMode, mode.name);
  }

  Future<void> setFlavor(AppThemeFlavor flavor) async {
    state = state.copyWith(flavor: flavor);
    await _storage.setString(StorageKeys.themeFlavor, flavor.name);
  }

  static ThemeMode _modeFromName(String? name) => switch (name) {
        'dark' => ThemeMode.dark,
        _ => ThemeMode.light,
      };
}

final themeProvider =
    NotifierProvider<ThemeController, ThemeSettings>(ThemeController.new);
