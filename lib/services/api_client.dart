import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models.dart';
import 'auth_service.dart';

/// The only place that calls the game backend. The backend decides every
/// resource change and score; the app just shows what comes back.
class ApiClient {
  ApiClient(this.auth);

  final AuthService auth;

  Future<GameConfig> gameConfig() async {
    return GameConfig.fromJson(await _send('GET', '/api/v1/game/config', authed: false));
  }

  Future<List<Mission>> missions({String? status, int limit = 20}) async {
    final query = <String, String>{'limit': '$limit'};
    if (status != null) query['status'] = status;
    final data = await _send('GET', '/api/v1/missions', query: query);
    final items = data['items'];
    return [
      if (items is List)
        for (final m in items) Mission.fromJson((m as Map).cast<String, dynamic>()),
    ];
  }

  Future<Mission> createMission() async {
    return Mission.fromJson(await _send('POST', '/api/v1/missions', body: <String, dynamic>{}));
  }

  Future<DecisionResult> decide({
    required String missionId,
    required String decisionType,
    required String option,
    required String requestId,
    required int expectedVersion,
  }) async {
    final data = await _send('POST', '/api/v1/missions/$missionId/decision', body: {
      'decision_type': decisionType,
      'selected_option': option,
      'request_id': requestId,
      'expected_version': expectedVersion,
    });
    return DecisionResult(
      Mission.fromJson((data['mission'] as Map).cast<String, dynamic>()),
      Outcome.fromJson((data['outcome'] as Map).cast<String, dynamic>()),
    );
  }

  Future<SpaceWeather> spaceWeather({int days = 7, int limit = 60}) async {
    return SpaceWeather.fromJson(await _send('GET', '/api/v1/nasa/space-weather',
        query: {'days': '$days', 'limit': '$limit'}, timeout: const Duration(seconds: 70)));
  }

  Future<ResearchResult> research(String term, {int limit = 5}) async {
    return ResearchResult.fromJson(await _send('GET', '/api/v1/nasa/health-research',
        query: {'term': term, 'limit': '$limit'}));
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool authed = true,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    var uri = Uri.parse('${AppConfig.apiBase}$path');
    if (query != null) uri = uri.replace(queryParameters: query);

    for (var attempt = 0; attempt < 2; attempt++) {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (authed) {
        final token = await auth.accessToken(forceRefresh: attempt == 1);
        if (token == null) throw ApiException(401, 'missing_token', 'Please sign in again.');
        headers['Authorization'] = 'Bearer $token';
      }

      http.Response res;
      try {
        final request = method == 'GET'
            ? http.get(uri, headers: headers)
            : http.post(uri, headers: headers, body: jsonEncode(body ?? <String, dynamic>{}));
        res = await request.timeout(timeout);
      } catch (_) {
        throw ApiException(0, 'network', 'Cannot reach Mission Control. Check your connection and try again.');
      }

      if (res.statusCode == 401 && authed && attempt == 0) continue;

      Map<String, dynamic> data = <String, dynamic>{};
      try {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map) data = decoded.cast<String, dynamic>();
      } catch (_) {}

      if (res.statusCode >= 200 && res.statusCode < 300) return data;

      final error = data['error'];
      if (error is Map) {
        final details = error['details'];
        throw ApiException(
          res.statusCode,
          (error['code'] ?? 'error').toString(),
          (error['message'] ?? 'Something went wrong.').toString(),
          details is Map ? details.cast<String, dynamic>() : const <String, dynamic>{},
        );
      }
      throw ApiException(res.statusCode, 'error', 'Mission Control had a problem. Please try again.');
    }
    throw ApiException(401, 'invalid_token', 'Please sign in again.');
  }
}
