import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LocalStorage {
  static late Box _box;

  // Credentials live in the platform keystore (Android Keystore / iOS Keychain),
  // not in the plain Hive box.
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> init() async {
    _box = await Hive.openBox('vendor_box');
    // One-time migration for sessions saved by older versions.
    for (final key in const ['token', 'refresh_token']) {
      final old = _box.get(key);
      if (old is String && old.isNotEmpty) {
        try {
          if (await _secure.read(key: key) == null) {
            await _secure.write(key: key, value: old);
          }
          await _box.delete(key);
        } catch (_) {
          // Keystore unavailable: leave the old value so the vendor stays signed in.
        }
      }
    }
  }

  // Token helpers
  static Future<void> setToken(String v) => _secure.write(key: 'token', value: v);
  static Future<String?> getToken() async {
    try {
      return await _secure.read(key: 'token') ?? _box.get('token') as String?;
    } catch (_) {
      return _box.get('token') as String?;
    }
  }

  static Future<void> setRefreshToken(String v) =>
      _secure.write(key: 'refresh_token', value: v);
  static Future<String?> getRefreshToken() async {
    try {
      return await _secure.read(key: 'refresh_token') ??
          _box.get('refresh_token') as String?;
    } catch (_) {
      return _box.get('refresh_token') as String?;
    }
  }

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

  // Full clear
  static Future<void> clearAll() async {
    await _box.clear();
    try {
      await _secure.deleteAll();
    } catch (_) {}
  }
}
