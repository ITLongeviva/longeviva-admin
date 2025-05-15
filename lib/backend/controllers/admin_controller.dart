import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../shared/utils/error_handler.dart';
import '../models/admin_model.dart';
import '../repositories/admin_repository.dart';

class AdminController {
  final AdminRepository _adminRepository;
  final FlutterSecureStorage _secureStorage;
  static const String _adminTokenKey = 'admin_token';
  static const String _adminEmailKey = 'admin_email';
  static const String _adminExpireKey = 'admin_expire';

  AdminController({
    AdminRepository? adminRepository,
    FlutterSecureStorage? secureStorage,
  }) :
        _adminRepository = adminRepository ?? AdminRepository(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<Admin?> loginAdmin({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      ErrorHandler.logDebug('Attempting admin login for: $email');

      if (email.isEmpty) {
        throw AppException(
          'Email is required',
          translationKey: 'errors.auth.email_required',
        );
      }
      if (password.isEmpty) {
        throw AppException(
          'Password is required',
          translationKey: 'errors.auth.password_required',
        );
      }

      final admin = await _adminRepository.loginAdmin(email, password);

      if (admin == null) {
        throw AppException(
          'Invalid admin credentials',
          translationKey: 'errors.auth.invalid_admin_credentials',
        );
      }

      final expireDate = DateTime.now().add(const Duration(days: 1)).toIso8601String();
      await _secureStorage.write(key: _adminEmailKey, value: email);
      await _secureStorage.write(key: _adminTokenKey, value: 'admin-token-for-${admin.id}');
      await _secureStorage.write(key: _adminExpireKey, value: expireDate);

      ErrorHandler.logDebug('Admin credentials stored for: $email until $expireDate');

      return admin;
    } catch (e) {
      ErrorHandler.logError('Admin login error', e);
      rethrow;
    }
  }

  Future<void> logoutAdmin() async {
    try {
      ErrorHandler.logDebug('Logging out admin');

      await _secureStorage.delete(key: _adminEmailKey);
      await _secureStorage.delete(key: _adminTokenKey);
      await _secureStorage.delete(key: _adminExpireKey);

      ErrorHandler.logDebug('Admin logged out successfully');
    } catch (e) {
      ErrorHandler.logError('Admin logout error', e);
      rethrow;
    }
  }

  Future<Admin?> checkAdminAuth() async {
    try {
      final email = await _secureStorage.read(key: _adminEmailKey);
      final token = await _secureStorage.read(key: _adminTokenKey);
      final expireStr = await _secureStorage.read(key: _adminExpireKey);

      if (email == null || token == null || expireStr == null) {
        ErrorHandler.logDebug('No stored admin credentials found');
        return null;
      }

      final expireDate = DateTime.parse(expireStr);
      if (DateTime.now().isAfter(expireDate)) {
        ErrorHandler.logDebug('Stored admin credentials expired');
        await logoutAdmin();
        return null;
      }

      ErrorHandler.logDebug('Valid stored admin credentials found for: $email');

      return Admin(
        id: token.replaceAll('admin-token-for-', ''),
        email: email,
        name: 'Admin User',
        password: '',
      );
    } catch (e) {
      ErrorHandler.logError('Check admin auth error', e);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getSignupRequests() async {
    try {
      return await _adminRepository.getSignupRequests();
    } catch (e) {
      ErrorHandler.logError('Error getting signup requests', e);
      rethrow;
    }
  }

  Future<bool> rejectSignupRequest(String requestId) async {
    try {
      return await _adminRepository.rejectSignupRequest(requestId);
    } catch (e) {
      ErrorHandler.logError('Error rejecting signup request', e);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      return await _adminRepository.getAllUsers();
    } catch (e) {
      ErrorHandler.logError('Error getting all users', e);
      rethrow;
    }
  }

  Future<bool> deleteUser(String userId, String userType) async {
    try {
      return await _adminRepository.deleteUser(userId, userType);
    } catch (e) {
      ErrorHandler.logError('Error deleting user', e);
      return false;
    }
  }
}