import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LocalStorage {
  static late Box _box;

  // Login credentials live in the platform keystore (Android Keystore / iOS
  // Keychain), not in the plain Hive box: a session that lasts months should
  // not sit in a readable file.
  static FlutterSecureStorage _secure = const FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _refreshKey = 'refresh_token';

  /// Test hook: swap the secure storage implementation.
  static void useSecureStorage(FlutterSecureStorage s) => _secure = s;

  static Future<void> init() async {
    _box = await Hive.openBox('vendor_box');
  }

  // ── Secure helpers: never throw. A keystore read can fail (for example
  // after a phone restore); that must mean "signed out", never a crash. ──
  static Future<String?> _readSecure(String key) async {
    try {
      return await _secure.read(key: key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeSecure(String key, String value) async {
    try {
      await _secure.write(key: key, value: value);
    } catch (_) {}
  }

  // Token helpers
  static Future<void> setToken(String v) async {
    await _writeSecure(_tokenKey, v);
    await _box.delete('token'); // legacy plain-text copy
  }

  static Future<String?> getToken() async {
    final secure = await _readSecure(_tokenKey);
    if (secure != null && secure.isNotEmpty) return secure;
    // One-time migration for vendors who signed in before secure storage.
    final legacy = _box.get('token');
    if (legacy is String && legacy.isNotEmpty) {
      await setToken(legacy);
      return legacy;
    }
    return null;
  }

  // Long-lived token used to renew the session without asking for a password.
  static Future<void> setRefreshToken(String v) async =>
      _writeSecure(_refreshKey, v);
  static Future<String?> getRefreshToken() async => _readSecure(_refreshKey);

  // Generic string helpers (used by login screen etc.)
  static Future<void> setString(String key, String value) async =>
      _box.put(key, value);
  static Future<String?> getString(String key) async => _box.get(key);
  static Future<void> remove(String key) async => _box.delete(key);

  // Vendor profile cache — populated from VendorAuthApi.login's merged
  // account+roleData payload, and refreshed from GET /auth/profile.
  // Lets Settings show real business_name/contact_person/etc. instead of
  // placeholder text while a fresh network call is in flight.
  static Future<void> setVendorProfile(Map<String, dynamic> profile) async =>
      _box.put('vendor_profile', jsonEncode(profile));

  static Future<Map<String, dynamic>?> getVendorProfile() async {
    final raw = _box.get('vendor_profile');
    if (raw == null) return null;
    try {
      return jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // Small JSON cache so list screens can still show the last known data
  // when the network is down.
  static Future<void> cacheJson(String key, Object value) async {
    try {
      await _box.put('cache_$key', jsonEncode(value));
    } catch (_) {}
  }

  static Object? readCachedJson(String key) {
    try {
      final raw = _box.get('cache_$key');
      if (raw == null) return null;
      return jsonDecode(raw as String);
    } catch (_) {
      return null;
    }
  }

  // Full clear (sign out)
  static Future<void> clearAll() async {
    try {
      await _secure.delete(key: _tokenKey);
      await _secure.delete(key: _refreshKey);
    } catch (_) {}
    await _box.clear();
  }
}
