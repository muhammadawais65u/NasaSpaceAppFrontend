class ApiException implements Exception {
  ApiException(this.status, this.code, this.message, [this.details = const {}]);

  final int status;
  final String code;
  final String message;
  final Map<String, dynamic> details;

  @override
  String toString() => message;
}

const List<String> resourceKeys = [
  'oxygen_level',
  'power_level',
  'water_level',
  'food_level',
  'radiation_protection_level',
];

int _int(dynamic v) => (v as num).toInt();

Map<String, dynamic> _map(dynamic v) {
  return v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
}

List<dynamic> _list(dynamic v) => v is List ? v : const [];

Map<String, int> _intMap(dynamic v) {
  final out = <String, int>{};
  if (v is Map) {
    v.forEach((key, value) {
      if (value is num) out[key.toString()] = value.toInt();
    });
  }
  return out;
}

class Mission {
  Mission({
    required this.id,
    required this.status,
    required this.currentDay,
    required this.totalDays,
    required this.levels,
    required this.score,
    required this.alertLevel,
    required this.scenarioEventId,
    required this.version,
  });

  final String id;
  final String status;
  final int currentDay;
  final int totalDays;
  final Map<String, int> levels;
  final int score;
  final String alertLevel;
  final String? scenarioEventId;
  final int version;

  bool get isActive => status == 'active';

  factory Mission.fromJson(Map<String, dynamic> j) {
    return Mission(
      id: j['id'] as String,
      status: j['mission_status'] as String,
      currentDay: _int(j['current_day']),
      totalDays: _int(j['total_days']),
      levels: {for (final k in resourceKeys) k: _int(j[k])},
      score: _int(j['score']),
      alertLevel: j['alert_level'] as String,
      scenarioEventId: j['scenario_event_id'] as String?,
      version: _int(j['version']),
    );
  }
}

class Outcome {
  Outcome({
    required this.decisionEffects,
    required this.dailyDrain,
    required this.resourceChanges,
    required this.balanceBonus,
    required this.scoreChange,
    required this.dayPlayed,
    required this.result,
    required this.feedback,
  });

  final Map<String, int> decisionEffects;
  final Map<String, int> dailyDrain;
  final Map<String, int> resourceChanges;
  final bool balanceBonus;
  final int scoreChange;
  final int dayPlayed;

  /// null while playing, otherwise "completed" or "failed".
  final String? result;
  final String feedback;

  factory Outcome.fromJson(Map<String, dynamic> j) {
    return Outcome(
      decisionEffects: _intMap(j['decision_effects']),
      dailyDrain: _intMap(j['daily_drain']),
      resourceChanges: _intMap(j['resource_changes']),
      balanceBonus: j['balance_bonus'] == true,
      scoreChange: _int(j['score_change']),
      dayPlayed: _int(j['day_played']),
      result: j['result'] as String?,
      feedback: (j['feedback'] ?? '').toString(),
    );
  }
}

class DecisionResult {
  DecisionResult(this.mission, this.outcome);

  final Mission mission;
  final Outcome outcome;
}

class DecisionOption {
  DecisionOption({
    required this.id,
    required this.label,
    required this.lesson,
    required this.effects,
  });

  final String id;
  final String label;
  final String lesson;
  final Map<String, int> effects;
}

class MissionInfo {
  MissionInfo({
    required this.day,
    required this.title,
    required this.description,
    required this.scenario,
    required this.decisionType,
    required this.objectives,
    required this.options,
  });

  final int day;
  final String title;
  final String description;
  final String scenario;
  final String decisionType;
  final List<String> objectives;
  final List<DecisionOption> options;
}

class GameConfig {
  GameConfig({required this.missions, required this.dailyDrain});

  final List<MissionInfo> missions;
  final Map<String, int> dailyDrain;

  factory GameConfig.fromJson(Map<String, dynamic> j) {
    final decisions = _map(j['decisions']);
    final missions = <MissionInfo>[];
    for (final raw in _list(j['missions'])) {
      final m = _map(raw);
      final type = m['decision_type'].toString();
      final options = <DecisionOption>[];
      _map(decisions[type]).forEach((id, value) {
        final o = _map(value);
        options.add(DecisionOption(
          id: id,
          label: o['label'].toString(),
          lesson: o['lesson'].toString(),
          effects: _intMap(o['effects']),
        ));
      });
      missions.add(MissionInfo(
        day: _int(m['day']),
        title: m['title'].toString(),
        description: m['description'].toString(),
        scenario: m['scenario'].toString(),
        decisionType: type,
        objectives: [for (final o in _list(m['objectives'])) o.toString()],
        options: options,
      ));
    }
    return GameConfig(
        missions: missions, dailyDrain: _intMap(j['daily_drain']));
  }
}

class SpaceEvent {
  SpaceEvent({
    required this.id,
    required this.type,
    required this.date,
    required this.title,
    required this.details,
    required this.link,
  });

  final String id;

  /// FLR (solar flare), CME (coronal mass ejection) or GST (geomagnetic storm).
  final String type;
  final DateTime? date;
  final String title;
  final Map<String, dynamic> details;
  final String? link;

  factory SpaceEvent.fromJson(Map<String, dynamic> j) {
    final summary = _map(j['summary']);
    return SpaceEvent(
      id: j['id'].toString(),
      type: j['event_type'].toString(),
      date: DateTime.tryParse((j['event_date'] ?? '').toString()),
      title: (summary['title'] ?? 'Space weather event').toString(),
      details: _map(summary['details']),
      link: summary['link']?.toString(),
    );
  }
}

class SpaceWeather {
  SpaceWeather({
    required this.dataStatus,
    required this.retrievedAt,
    required this.events,
    required this.alertLevel,
    required this.basisEventId,
  });

  /// live, cached, archived or unavailable.
  final String dataStatus;
  final DateTime? retrievedAt;
  final List<SpaceEvent> events;

  /// Game simulation, not a NASA measurement: calm, watch or storm.
  final String alertLevel;
  final String? basisEventId;

  SpaceEvent? eventById(String? id) {
    if (id == null) return null;
    for (final e in events) {
      if (e.id == id) return e;
    }
    return null;
  }

  factory SpaceWeather.fromJson(Map<String, dynamic> j) {
    final scenario = _map(j['game_scenario']);
    return SpaceWeather(
      dataStatus: (j['data_status'] ?? 'unavailable').toString(),
      retrievedAt: DateTime.tryParse((j['retrieved_at'] ?? '').toString()),
      events: [
        for (final e in _list(j['events'])) SpaceEvent.fromJson(_map(e))
      ],
      alertLevel: (scenario['alert_level'] ?? 'calm').toString(),
      basisEventId: scenario['basis_event_id']?.toString(),
    );
  }
}

class Study {
  Study({
    required this.accession,
    required this.title,
    required this.description,
    required this.organism,
    required this.link,
  });

  final String accession;
  final String title;
  final String? description;
  final String? organism;
  final String link;

  factory Study.fromJson(Map<String, dynamic> j) {
    return Study(
      accession: j['accession'].toString(),
      title: j['title'].toString(),
      description: j['description']?.toString(),
      organism: j['organism']?.toString(),
      link: (j['link'] ?? '').toString(),
    );
  }
}

class ResearchResult {
  ResearchResult(
      {required this.dataStatus,
      required this.totalMatches,
      required this.studies});

  final String dataStatus;
  final int? totalMatches;
  final List<Study> studies;

  factory ResearchResult.fromJson(Map<String, dynamic> j) {
    final total = j['total_matches'];
    return ResearchResult(
      dataStatus: (j['data_status'] ?? 'unavailable').toString(),
      totalMatches: total is num ? total.toInt() : null,
      studies: [for (final s in _list(j['studies'])) Study.fromJson(_map(s))],
    );
  }
}
