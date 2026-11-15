import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'api_client.dart';
import 'auth_service.dart';

enum AppPhase { loading, error, ready }

/// Holds what the screens show. It never calculates game results itself.
class GameController extends ChangeNotifier {
  GameController() {
    api = ApiClient(auth);
  }

  static const String _astronautKey = 'player.astronaut';
  static const String _nameKey = 'player.name';
  static const List<String> astronauts = ['alex', 'emma', 'noah'];

  final AuthService auth = AuthService();
  late final ApiClient api;

  AppPhase phase = AppPhase.loading;
  String? errorMessage;

  GameConfig? config;

  /// The active mission, or the one that just ended.
  Mission? mission;
  SpaceWeather? weather;
  bool weatherLoading = false;
  int bestScore = 0;
  String astronaut = astronauts.first;
  String playerName = '';

  final Map<String, String> _pendingRequestIds = {};

  /// True once the player has typed a name and has a saved guest session.
  bool get signedIn => auth.isSignedIn;

  bool get hasActiveMission => mission != null && mission!.isActive;

  /// The real NASA event that set this mission's alert level, if we have it.
  SpaceEvent? get scenarioEvent => weather?.eventById(mission?.scenarioEventId);

  MissionInfo? missionInfo(int day) {
    final c = config;
    if (c == null) return null;
    for (final m in c.missions) {
      if (m.day == day) return m;
    }
    return null;
  }

  /// Opens the app on the main menu. Signing in happens later, with just a name.
  Future<void> start() async {
    phase = AppPhase.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_astronautKey);
      if (saved != null && astronauts.contains(saved)) astronaut = saved;
      playerName = prefs.getString(_nameKey) ?? '';

      config ??= await api.gameConfig();
      if (auth.isSignedIn || await auth.restore()) await _loadMissions();
      phase = AppPhase.ready;
      notifyListeners();
      refreshWeather();
    } on ApiException catch (e) {
      errorMessage = e.message;
      phase = AppPhase.error;
      notifyListeners();
    } catch (_) {
      // Anything unexpected (timeouts, socket errors) must not leave the
      // splash stuck on "Contacting Mission Control" forever.
      errorMessage = 'Cannot reach Mission Control.';
      phase = AppPhase.error;
      notifyListeners();
    }
  }

  /// The only sign-in step: the player types a first name.
  Future<void> signInWithName(String name) async {
    if (!auth.isSignedIn) await auth.signInAsGuest();
    playerName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
    await _loadMissions();
    notifyListeners();
    refreshWeather();
  }

  /// Forgets this player on this device and returns to the main menu.
  Future<void> signOut() async {
    await auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_nameKey);
    playerName = '';
    mission = null;
    bestScore = 0;
    weather = null;
    notifyListeners();
  }

  Future<void> setAstronaut(String id) async {
    astronaut = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_astronautKey, id);
  }

  /// Starts a new mission, or resumes the one that is already running.
  Future<Mission> startMission() async {
    try {
      mission = await api.createMission();
    } on ApiException catch (e) {
      if (e.code != 'active_mission_exists') rethrow;
      final active = await api.missions(status: 'active', limit: 1);
      if (active.isEmpty) rethrow;
      mission = active.first;
    }
    notifyListeners();
    refreshWeather();
    return mission!;
  }

  Future<DecisionResult> decide(MissionInfo info, DecisionOption option) async {
    final current = mission;
    if (current == null) throw ApiException(409, 'mission_not_active', 'There is no mission running.');
    // The same id is reused when the player retries, so a choice is never counted twice.
    final key = '${current.id}:${current.currentDay}:${option.id}';
    final requestId = _pendingRequestIds.putIfAbsent(key, _uuid);
    try {
      final result = await api.decide(
        missionId: current.id,
        decisionType: info.decisionType,
        option: option.id,
        requestId: requestId,
        expectedVersion: current.version,
      );
      _pendingRequestIds.remove(key);
      mission = result.mission;
      if (!result.mission.isActive && result.mission.score > bestScore) {
        bestScore = result.mission.score;
      }
      notifyListeners();
      return result;
    } on ApiException catch (e) {
      if (e.code == 'version_conflict' || e.code == 'mission_not_active') {
        _pendingRequestIds.remove(key);
        await reloadMission();
      }
      rethrow;
    }
  }

  Future<void> reloadMission() async {
    final active = await api.missions(status: 'active', limit: 1);
    mission = active.isEmpty ? null : active.first;
    notifyListeners();
  }

  /// NASA data is helpful but never blocks the game.
  Future<void> refreshWeather() async {
    if (weatherLoading || !signedIn) return;
    weatherLoading = true;
    notifyListeners();
    try {
      weather = await api.spaceWeather();
    } on ApiException {
      // Keep whatever we had; the screens show an honest "not available" label.
    } finally {
      weatherLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadMissions() async {
    final all = await api.missions(limit: 100);
    mission = null;
    bestScore = 0;
    for (final m in all) {
      if (m.isActive) {
        mission ??= m;
      } else if (m.score > bestScore) {
        bestScore = m.score;
      }
    }
  }

  static String _uuid() {
    final rnd = Random.secure();
    final b = List<int>.generate(16, (_) => rnd.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final hex = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

/// Makes the controller available to every screen and rebuilds them on change.
class GameScope extends InheritedNotifier<GameController> {
  const GameScope({super.key, required GameController controller, required super.child})
      : super(notifier: controller);

  static GameController of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GameScope>()!.notifier!;
  }
}
