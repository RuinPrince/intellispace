import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../models/user.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_config.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AppRole? get role => _currentUser?.role;

  final ApiClient _api = ApiClient();

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final clean = email.trim();
      final pass = password.trim();
      final isNumeric = int.tryParse(clean) != null;
      final path = isNumeric
          ? '/users?or=(email.eq.$clean,name.eq.$clean,id.eq.$clean)&password=eq.$pass&select=*'
          : '/users?or=(email.eq.$clean,name.eq.$clean)&password=eq.$pass&select=*';

      final response = await _api.get(path);

      if (response is List && response.isNotEmpty) {
        final userData = response[0] as Map<String, dynamic>;
        await _api.setToken(ApiConfig.supabaseAnonKey);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_session', jsonEncode(userData));
        await prefs.setString('user_saved_password', pass);

        _currentUser = User.fromJson(userData);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Invalid email/username or password.';
      }
    } catch (e) {
      _errorMessage = 'Connection failed: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }
  
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_session');
      if (userJson != null) {
        final userData = jsonDecode(userJson);
        _currentUser = User.fromJson(userData);
      }
    } catch (e) {
      _currentUser = null;
    }
    
    _isLoading = false;
    notifyListeners();
  }

  bool get isAdmin => _currentUser?.role == AppRole.administrator;

  Future<bool> updateProfile({
    required String name,
    required String email,
    required String department,
  }) async {
    if (_currentUser == null) return false;

    final updated = _currentUser!.copyWith(
      name: name,
      email: email,
      department: department,
    );

    _currentUser = updated;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_session', jsonEncode(updated.toJson()));

      // Update Supabase users table
      await _api.patch(
        '/users?id=eq.${updated.id}',
        body: {
          'name': name,
          'email': email,
          'department': department,
        },
      );
      return true;
    } catch (e) {
      print('Error updating user profile in Supabase: $e');
      return true; // Still true since local session was updated
    }
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (_currentUser == null) return false;
    _errorMessage = null;

    final cleanOld = oldPassword.trim();
    final cleanNew = newPassword.trim();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPassword = prefs.getString('user_saved_password');

      // 1. If stored locally, check immediate match
      if (savedPassword != null && savedPassword.isNotEmpty && savedPassword != cleanOld) {
        _errorMessage = 'Current password does not match!';
        notifyListeners();
        return false;
      }

      // 2. Verify old password against Supabase PostgreSQL
      final check = await _api.get(
        '/users?id=eq.${_currentUser!.id}&password=eq.${Uri.encodeComponent(cleanOld)}&select=id',
      );
      if (check is! List || check.isEmpty) {
        _errorMessage = 'Current password does not match!';
        notifyListeners();
        return false;
      }

      // 3. Update to new password in Supabase
      await _api.patch(
        '/users?id=eq.${_currentUser!.id}',
        body: {'password': cleanNew},
      );

      // 4. Update local cached password
      await prefs.setString('user_saved_password', cleanNew);

      // Also update session cache
      final userJson = prefs.getString('user_session');
      if (userJson != null) {
        final Map<String, dynamic> sessionData = jsonDecode(userJson);
        sessionData['password'] = cleanNew;
        await prefs.setString('user_session', jsonEncode(sessionData));
      }

      notifyListeners();
      return true;
    } catch (e) {
      print('Error changing password: $e');
      _errorMessage = 'Failed to change password: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyAdminPassword(String password) async {
    if (_currentUser == null) return false;
    try {
      final res = await _api.get(
        '/users?id=eq.${_currentUser!.id}&password=eq.$password&select=id',
      );
      return (res is List && res.isNotEmpty);
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_session');
    await _api.clearToken();
    _currentUser = null;
    
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createTeacher({
    required String name,
    required String email,
    required String password,
    String? department,
  }) async {
    try {
      await _api.post('/users', body: {
        'name': name,
        'email': email,
        'password': password,
        'role': 'teacher',
        'department': department ?? '',
      });
      return true;
    } catch (e) {
      _errorMessage = 'Failed to create teacher: $e';
      notifyListeners();
      return false;
    }
  }
}
