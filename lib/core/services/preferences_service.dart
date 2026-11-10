import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/app_settings.dart';

/// Thin wrapper around [SharedPreferences] for persisting global app settings.
///
/// Keep all preference keys here so storage access stays centralized and easy
/// to swap for another backend later.
class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  static const String _themeModeKey = 'theme_mode';
  static const String _recentDeviceIdsKey = 'recent_device_ids';
  static const String _recentHouseIdsKey = 'recent_house_ids';
  static const String _favoriteDeviceIdsPrefix = 'favorite_device_ids_';
  static const String _startRouteKeyPrefix = 'start_route_';
  static const String _appSettingsKeyPrefix = 'app_settings_';

  static const int maxRecentDevices = 3;
  static const int maxRecentHouses = 2;

  ThemeMode get themeMode {
    final value = _prefs.getString(_themeModeKey);
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  /// Whether the user has explicitly chosen light or dark (not system default).
  bool get hasStoredThemeMode => _prefs.containsKey(_themeModeKey);

  Future<void> setThemeMode(ThemeMode mode) {
    return _prefs.setString(_themeModeKey, mode.name);
  }

  List<String> get recentDeviceIds =>
      _prefs.getStringList(_recentDeviceIdsKey) ?? const [];

  Future<void> setRecentDeviceIds(List<String> ids) {
    return _prefs.setStringList(_recentDeviceIdsKey, ids);
  }

  List<String> favoriteDeviceIds(String userId) =>
      _prefs.getStringList('$_favoriteDeviceIdsPrefix$userId') ?? const [];

  Future<void> setFavoriteDeviceIds(String userId, List<String> ids) {
    return _prefs.setStringList('$_favoriteDeviceIdsPrefix$userId', ids);
  }

  List<String> get recentHouseIds =>
      _prefs.getStringList(_recentHouseIdsKey) ?? const [];

  Future<void> setRecentHouseIds(List<String> ids) {
    return _prefs.setStringList(_recentHouseIdsKey, ids);
  }

  String? startRouteForUser(String userId) {
    return _prefs.getString('$_startRouteKeyPrefix$userId');
  }

  Future<void> setStartRouteForUser(String userId, String route) {
    return _prefs.setString('$_startRouteKeyPrefix$userId', route);
  }

  /// Device-local app settings for [userId]. Dark mode comes from [themeMode].
  AppSettings loadAppSettings(String userId) {
    final stored = _readAppSettingsMap(userId);
    final legacyStart = startRouteForUser(userId);
    return AppSettings(
      userId: userId,
      darkMode: themeMode == ThemeMode.dark,
      language: stored?['language'] as String? ?? 'de',
      biometricEnabled: stored?['biometricEnabled'] as bool? ?? false,
      pinEnabled: stored?['pinEnabled'] as bool? ?? false,
      twoFactorEnabled: stored?['twoFactorEnabled'] as bool? ?? false,
      connectionMode: stored?['connectionMode'] as String? ?? 'cloud',
      showRecentActivity: stored?['showRecentActivity'] as bool? ?? true,
      showFavorites: stored?['showFavorites'] as bool? ?? true,
      startRoute: stored?['startRoute'] as String? ??
          (legacyStart != null && legacyStart.isNotEmpty
              ? legacyStart
              : '/home'),
    );
  }

  /// True once [pinEnabled] was written locally (not inferred from a PIN hash).
  bool hasStoredPinEnabled(String userId) {
    return _readAppSettingsMap(userId)?.containsKey('pinEnabled') ?? false;
  }

  Future<void> saveAppSettings(AppSettings settings) async {
    final payload = <String, Object>{
      'language': settings.language,
      'biometricEnabled': settings.biometricEnabled,
      'pinEnabled': settings.pinEnabled,
      'twoFactorEnabled': settings.twoFactorEnabled,
      'connectionMode': settings.connectionMode,
      'showRecentActivity': settings.showRecentActivity,
      'showFavorites': settings.showFavorites,
      'startRoute': settings.startRoute,
    };
    await _prefs.setString(
      '$_appSettingsKeyPrefix${settings.userId}',
      jsonEncode(payload),
    );
    await setThemeMode(settings.darkMode ? ThemeMode.dark : ThemeMode.light);
    await setStartRouteForUser(settings.userId, settings.startRoute);
  }

  Map<String, dynamic>? _readAppSettingsMap(String userId) {
    final raw = _prefs.getString('$_appSettingsKeyPrefix$userId');
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }
}

/// Provides the [PreferencesService]. Overridden in `main()` with the resolved
/// [SharedPreferences] instance so it is available synchronously everywhere.
final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  throw UnimplementedError(
    'preferencesServiceProvider must be overridden in main()',
  );
});
