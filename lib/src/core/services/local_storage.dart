import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class LocalStorage {
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox('vendor_box');
  }

  // Token helpers
  static Future<void> setToken(String v) async => _box.put('token', v);
  static Future<String?> getToken() async => _box.get('token');

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

  // Full clear
  static Future<void> clearAll() async => _box.clear();
}
