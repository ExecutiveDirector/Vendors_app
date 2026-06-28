import 'dart:async';
import 'package:dio/dio.dart';
import '../../../core/api/dio_client.dart';

/// Handles all vendor authentication API interactions.
class VendorAuthApi {
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      final res = await ApiClient.dio.post(
        '/auth/login', // ✅ FIX: was '/vendors/login' — no such route exists
        data: {'email': email.trim(), 'password': password},
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      return _normalizeResponse(res.data);
    } on DioException catch (e) {
      throw Exception(_handleDioError(e)); // ✅ FIX: throw Exception not String
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Vendor Registration
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    required String businessName,
    required String phone,
    String? tradingName,
    String? brand,
  }) async {
    try {
      final res = await ApiClient.dio.post(
        '/auth/register/vendor', // ✅ FIX: unified auth namespace
        data: {
          'email': email.trim(),
          'password': password,
          'businessName': businessName.trim(),
          'contactPerson': fullName.trim(),
          'phone': phone.trim(),
          if (tradingName != null) 'trading_name': tradingName.trim(),
          if (brand != null) 'brand': brand.trim(),
        },
        options: Options(receiveTimeout: const Duration(seconds: 25)),
      );
      return _normalizeResponse(res.data);
    } on DioException catch (e) {
      throw Exception(_handleDioError(e)); // ✅ FIX: throw Exception not String
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Forgot Password
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final res = await ApiClient.dio.post(
        '/auth/forgot-password', // ✅ FIX: was '/vendors/forgot-password'
        data: {'email': email.trim()},
      );
      return _normalizeResponse(res.data);
    } on DioException catch (e) {
      throw Exception(_handleDioError(e)); // ✅ FIX: throw Exception not String
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Reset Password
  static Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final res = await ApiClient.dio.post(
        '/auth/reset-password', // ✅ FIX: was '/vendors/reset-password'
        data: {'token': token, 'new_password': newPassword},
      );
      return _normalizeResponse(res.data);
    } on DioException catch (e) {
      throw Exception(_handleDioError(e)); // ✅ FIX: throw Exception not String
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Vendor Profile — uses unified /auth/profile (authController.getProfile)
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final res = await ApiClient.dio
          .get('/auth/profile'); // ✅ FIX: was '/vendors/profile'
      return _normalizeResponse(res.data);
    } on DioException catch (e) {
      throw Exception(_handleDioError(e)); // ✅ FIX: throw Exception not String
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Update Profile — uses unified /auth/profile (authController.updateProfile)
  static Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> updates) async {
    try {
      final res = await ApiClient.dio.put(
        '/auth/profile',
        data: updates,
      );
      return _normalizeResponse(res.data);
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Change Password (also handles first-time password set for phone users)
  static Future<Map<String, dynamic>> changePassword({
    String? currentPassword, // optional — not required for first-time set
    required String newPassword,
  }) async {
    try {
      final res = await ApiClient.dio.post(
        '/auth/change-password',
        data: {
          if (currentPassword != null) 'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
      return _normalizeResponse(res.data);
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Check whether the authenticated user has set a password yet.
  /// Useful for phone-registered users who may not have one yet.
  static Future<Map<String, dynamic>> checkPasswordStatus() async {
    try {
      final res = await ApiClient.dio.get('/auth/password-status');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  static Future<void> logout() async {
    try {
      await ApiClient.dio.post('/auth/logout');
    } catch (_) {}
  }

  /// Verify Authentication Status
  static Future<bool> verifyAuth() async {
    try {
      final res = await ApiClient.dio.get('/auth/verify');
      return res.data['authenticated'] == true;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> _normalizeResponse(dynamic rawData) {
    if (rawData is! Map<String, dynamic>) {
      return {'success': true, 'data': rawData, 'message': 'Success'};
    }

    // Token lives at the top level in the backend response
    final token = rawData['token'];

    // Merge account + role-specific data into a unified user object.
    // Login (authController.login) returns the role-specific row under
    // 'roleData'; getProfile (authController.getProfile) returns the same
    // kind of data under 'profile' instead. Checking both keeps this
    // normalizer correct for both callers — previously it only read
    // 'roleData', so every getProfile() call silently dropped all vendor
    // fields (business_name, contact_person, etc.) and returned only the
    // bare account row.
    final account = rawData['account'] as Map<String, dynamic>? ?? {};
    final roleData = (rawData['roleData'] ?? rawData['profile'])
            as Map<String, dynamic>? ??
        {};

    // Resolve display name across all role types:
    // vendor → contact_person | rider/user → full_name or first_name | fallback → email
    final displayName = roleData['contact_person'] ??
        roleData['full_name'] ??
        roleData['first_name'] ??
        account['email'] ??
        'Vendor';

    final user = <String, dynamic>{
      ...account,
      ...roleData,
      'name': displayName,
    };

    return {
      'success': rawData['success'] ?? true,
      'message': rawData['message'] ?? 'Success',
      'data': {
        'token': token,
        'user': user,
        'role': rawData['role'],
        'redirect': rawData['redirect'],
      },
    };
  }

  static String _handleDioError(DioException e) {
    final statusCode = e.response?.statusCode ?? 0;
    final message = e.response?.data?['error'] ??
        e.response?.data?['message'] ??
        e.message ??
        'Unexpected network error';

    switch (statusCode) {
      case 400:
        return 'Bad request: $message';
      case 401:
        return 'Invalid email or password.';
      case 403:
        return 'Access denied. Account inactive or unauthorized.';
      case 404:
        return 'Service not found.';
      case 409:
        return 'This email or phone is already registered.';
      case 429:
        return 'Too many attempts. Please try again later.';
      case 500:
        return 'Server error. Please try again later.';
      default:
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          return 'Connection timeout. Please check your internet.';
        }
        if (e.type == DioExceptionType.unknown) {
          return 'Network issue. Please verify your connection.';
        }
        return 'Unexpected error: $message';
    }
  }
}
