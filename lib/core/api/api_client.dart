import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  String? _jwtToken;

  Future<void> setToken(String token) async {
    _jwtToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _jwtToken = prefs.getString('jwt_token');
  }

  Future<void> clearToken() async {
    _jwtToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  Map<String, String> _getHeaders({Map<String, String>? extraHeaders}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'apikey': ApiConfig.supabaseAnonKey,
      'Authorization': 'Bearer ${_jwtToken ?? ApiConfig.supabaseAnonKey}',
    };
    
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    
    return headers;
  }

  Future<dynamic> get(String endpoint, {Map<String, String>? headers}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final response = await http.get(url, headers: _getHeaders(extraHeaders: headers));
    return _processResponse(response);
  }

  Future<dynamic> post(String endpoint, {dynamic body, Map<String, String>? headers}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final response = await http.post(
      url,
      headers: _getHeaders(extraHeaders: headers),
      body: body != null ? jsonEncode(body) : null,
    );
    return _processResponse(response);
  }

  Future<dynamic> patch(String endpoint, {dynamic body, Map<String, String>? headers}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final response = await http.patch(
      url,
      headers: _getHeaders(extraHeaders: headers),
      body: body != null ? jsonEncode(body) : null,
    );
    return _processResponse(response);
  }

  Future<dynamic> put(String endpoint, {dynamic body, Map<String, String>? headers}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final response = await http.put(
      url,
      headers: _getHeaders(extraHeaders: headers),
      body: body != null ? jsonEncode(body) : null,
    );
    return _processResponse(response);
  }

  Future<dynamic> delete(String endpoint, {Map<String, String>? headers}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final response = await http.delete(url, headers: _getHeaders(extraHeaders: headers));
    return _processResponse(response);
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode == 204 || response.body.isEmpty) {
      return {'success': true};
    }

    final decoded = jsonDecode(response.body);
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic> && decoded.containsKey('success') && decoded['success'] == true) {
        return decoded['data'] ?? decoded;
      }
      return decoded;
    } else {
      final message = decoded is Map ? (decoded['message'] ?? decoded['hint'] ?? 'Request failed') : 'Unknown error';
      throw ApiException(response.statusCode, message.toString());
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException: [$statusCode] $message';
}
