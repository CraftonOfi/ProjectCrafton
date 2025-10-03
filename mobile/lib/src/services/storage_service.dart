import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';

import '../config/app_config.dart';
import '../models/user_model.dart';

class StorageService {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
   //   accessibility: KeychainItemAccessibility.first_unlock_this_device,
    ),
  );

  static late SharedPreferences _prefs;
  static late Box _box;

  // Inicializar servicios de almacenamiento
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _box = await Hive.openBox('app_storage');
  }

  // =================== TOKEN MANAGEMENT ===================
  
  static Future<void> saveToken(String token) async {
    await _secureStorage.write(key: AppConfig.tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _secureStorage.read(key: AppConfig.tokenKey);
  }

  static Future<void> clearToken() async {
    await _secureStorage.delete(key: AppConfig.tokenKey);
  }

  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // =================== USER DATA MANAGEMENT ===================
  
  static Future<void> saveUser(UserModel user) async {
    final userJson = jsonEncode(user.toJson());
    await _secureStorage.write(key: AppConfig.userKey, value: userJson);
  }

  static Future<UserModel?> getUser() async {
    try {
      final userJson = await _secureStorage.read(key: AppConfig.userKey);
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        return UserModel.fromJson(userMap);
      }
    } catch (e) {
      print('Error reading user data: $e');
    }
    return null;
  }

  static Future<void> clearUser() async {
    await _secureStorage.delete(key: AppConfig.userKey);
  }

  // =================== APP SETTINGS ===================
  
  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    final settingsJson = jsonEncode(settings);
    await _prefs.setString(AppConfig.settingsKey, settingsJson);
  }

  static Map<String, dynamic> getSettings() {
    try {
      final settingsJson = _prefs.getString(AppConfig.settingsKey);
      if (settingsJson != null) {
        return jsonDecode(settingsJson) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error reading settings: $e');
    }
    return {};
  }

  static Future<void> updateSetting(String key, dynamic value) async {
    final currentSettings = getSettings();
    currentSettings[key] = value;
    await saveSettings(currentSettings);
  }

  static T? getSetting<T>(String key, [T? defaultValue]) {
    final settings = getSettings();
    return settings[key] as T? ?? defaultValue;
  }

  // =================== CACHE MANAGEMENT ===================
  
  // Guardar datos en cache local (usando Hive)
  static Future<void> cacheData(String key, dynamic data) async {
    await _box.put(key, data);
  }

  // Obtener datos del cache
  static T? getCachedData<T>(String key) {
    return _box.get(key) as T?;
  }

  // Eliminar datos específicos del cache
  static Future<void> clearCachedData(String key) async {
    await _box.delete(key);
  }

  // Limpiar todo el cache
  static Future<void> clearAllCache() async {
    await _box.clear();
  }

  // =================== PREFERENCES HELPERS ===================
  
  // Guardar preferencias simples
  static Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  static bool getBool(String key, [bool defaultValue = false]) {
    return _prefs.getBool(key) ?? defaultValue;
  }

  static Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  static String getString(String key, [String defaultValue = '']) {
    return _prefs.getString(key) ?? defaultValue;
  }

  static Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  static int getInt(String key, [int defaultValue = 0]) {
    return _prefs.getInt(key) ?? defaultValue;
  }

  static Future<void> setDouble(String key, double value) async {
    await _prefs.setDouble(key, value);
  }

  static double getDouble(String key, [double defaultValue = 0.0]) {
    return _prefs.getDouble(key) ?? defaultValue;
  }

  // =================== ONBOARDING & FIRST TIME ===================
  
  static Future<void> setFirstTime(bool isFirstTime) async {
    await setBool('is_first_time', isFirstTime);
  }

  static bool isFirstTime() {
    return getBool('is_first_time', true);
  }

  static Future<void> setOnboardingCompleted(bool completed) async {
    await setBool('onboarding_completed', completed);
  }

  static bool isOnboardingCompleted() {
    return getBool('onboarding_completed', false);
  }

  // =================== THEME & UI PREFERENCES ===================
  
  static Future<void> setThemeMode(String themeMode) async {
    await setString('theme_mode', themeMode);
  }

  static String getThemeMode() {
    return getString('theme_mode', 'system');
  }

  static Future<void> setLanguage(String languageCode) async {
    await setString('language', languageCode);
  }

  static String getLanguage() {
    return getString('language', 'es');
  }

  // =================== CLEAR ALL DATA ===================
  
  static Future<void> clearAllData() async {
    await clearToken();
    await clearUser();
    await clearAllCache();
    await _prefs.clear();
  }

  // =================== OFFLINE SYNC ===================
  
  // Guardar acciones pendientes para cuando vuelva la conexión
  static Future<void> savePendingAction(Map<String, dynamic> action) async {
    final pendingActions = getPendingActions();
    pendingActions.add(action);
    await cacheData('pending_actions', pendingActions);
  }

  static List<Map<String, dynamic>> getPendingActions() {
    final actions = getCachedData<List>('pending_actions');
    return actions?.cast<Map<String, dynamic>>() ?? [];
  }

  static Future<void> clearPendingActions() async {
    await clearCachedData('pending_actions');
  }

  // =================== LAST SYNC TIMES ===================
  
  static Future<void> setLastSyncTime(String entity, DateTime time) async {
    await setString('last_sync_$entity', time.toIso8601String());
  }

  static DateTime? getLastSyncTime(String entity) {
    final timeString = getString('last_sync_$entity');
    return timeString.isNotEmpty ? DateTime.tryParse(timeString) : null;
  }
}