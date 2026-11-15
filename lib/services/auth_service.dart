import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models.dart';

/// Keeps a guest session on the device. Players never type an email or password:
/// the session is created for them and refreshed through Supabase Auth.
class AuthService {
  static const String _refreshKey = 'auth.refresh_token';

  String? _accessToken;
  String? _refreshToken;
  DateTime _expiresAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isSignedIn => _refreshToken != null;

  /// Restores a saved session. Returns false when there is none.
  Future<bool> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_refreshKey);
    if (saved == null || saved.isEmpty) return false;
    _refreshToken = saved;
    try {
      await _refresh();
      return true;
    } on ApiException catch (e) {
      if (e.status == 0) rethrow;
      await signOut();
      return false;
    }
  }

  /// Creates a new guest player. Uses Supabase anonymous sign-in when it is
  /// switched on, otherwise asks the game backend for a guest session.
  Future<void> signInAsGuest() async {
    try {
      await _post('${AppConfig.supabaseUrl}/auth/v1/signup', <String, dynamic>{},
          headers: {'apikey': AppConfig.supabaseAnonKey});
    } on ApiException catch (e) {
      if (e.status == 0) rethrow;
      await _post('${AppConfig.apiBase}/api/v1/auth/guest', <String, dynamic>{});
    }
  }

  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_refreshKey);
  }

  /// A valid access token, refreshed when it is about to expire.
  Future<String?> accessToken({bool forceRefresh = false}) async {
    if (_refreshToken == null) return null;
    final expiring = DateTime.now().isAfter(_expiresAt.subtract(const Duration(seconds: 60)));
    if (forceRefresh || _accessToken == null || expiring) {
      try {
        await _refresh();
      } on ApiException catch (e) {
        if (e.status == 0) rethrow;
        await signOut();
        return null;
      }
    }
    return _accessToken;
  }

  Future<void> _refresh() {
    return _post('${AppConfig.supabaseUrl}/auth/v1/token?grant_type=refresh_token',
        {'refresh_token': _refreshToken}, headers: {'apikey': AppConfig.supabaseAnonKey});
  }

  Future<void> _post(String url, Map<String, dynamic> body, {Map<String, String> headers = const {}}) async {
    http.Response res;
    try {
      res = await http
          .post(Uri.parse(url), headers: {'Content-Type': 'application/json', ...headers}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ApiException(0, 'network', 'Cannot reach Mission Control. Check your connection and try again.');
    }
    Map<String, dynamic> data = <String, dynamic>{};
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map) data = decoded.cast<String, dynamic>();
    } catch (_) {}
    final access = data['access_token'];
    final refresh = data['refresh_token'];
    if (res.statusCode < 200 || res.statusCode >= 300 || access is! String || refresh is! String) {
      final error = data['error'];
      final message = (error is Map ? error['message'] : null) ?? data['msg'] ?? 'Sign-in failed. Please try again.';
      throw ApiException(res.statusCode >= 400 ? res.statusCode : 401, 'auth_failed', message.toString());
    }
    _accessToken = access;
    _refreshToken = refresh;
    final expiresIn = data['expires_in'];
    _expiresAt = DateTime.now().add(Duration(seconds: expiresIn is num ? expiresIn.toInt() : 3600));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshKey, refresh);
  }
}
