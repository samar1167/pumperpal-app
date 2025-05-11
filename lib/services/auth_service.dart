import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';

  // Save auth token
  static Future<void> saveAuthToken(String token, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, userId);
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return token != null && token.isNotEmpty;
  }

  // Get auth token
  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Get user id
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  // Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }

  static Future<Map<String, dynamic>> getUserInfo() async {
    final token = await getAuthToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final payload = token.split('.')[1];
    final normalizedPayload = base64Url.normalize(payload);
    final decodedPayload = utf8.decode(base64Url.decode(normalizedPayload));
    final tokenData = jsonDecode(decodedPayload);
    if (tokenData is Map<String, dynamic> && tokenData.containsKey('user_id')) {
      tokenData['userId'] = tokenData.remove('user_id'); // a temp fix for the user_id key
    }
    return tokenData;
  }
}