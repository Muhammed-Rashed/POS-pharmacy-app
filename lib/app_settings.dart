import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const String _apiEndpointKey = 'api_endpoint';
  static const String _storeIdKey = 'store_id';
  static const String _terminalIdKey = 'terminal_id';
  static const String _authTokenKey = 'auth_token';
  static const String _autoSyncKey = 'auto_sync';
  static const String _syncIntervalKey = 'sync_interval';

  static Future<void> setApiEndpoint(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiEndpointKey, endpoint);
  }

  static Future<String> getApiEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiEndpointKey) ?? 'https://your-api-endpoint.com/api';
  }

  static Future<void> setStoreId(String storeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeIdKey, storeId);
  }

  static Future<String> getStoreId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storeIdKey) ?? '';
  }

  static Future<void> setTerminalId(String terminalId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_terminalIdKey, terminalId);
  }

  static Future<String> getTerminalId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_terminalIdKey) ?? '';
  }

  static Future<void> setAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, token);
  }

  static Future<String> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authTokenKey) ?? '';
  }

  static Future<void> setAutoSync(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncKey, enabled);
  }

  static Future<bool> getAutoSync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSyncKey) ?? true;
  }

  static Future<void> setSyncInterval(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_syncIntervalKey, minutes);
  }

  static Future<int> getSyncInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_syncIntervalKey) ?? 15; // Default 15 minutes
  }
}