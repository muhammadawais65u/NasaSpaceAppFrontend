import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junior_astronaut/models.dart';
import 'package:junior_astronaut/screens/home_screen.dart';
import 'package:junior_astronaut/screens/hub_screen.dart';
import 'package:junior_astronaut/screens/learning_screen.dart';
import 'package:junior_astronaut/screens/name_screen.dart';
import 'package:junior_astronaut/screens/mission_screen.dart';
import 'package:junior_astronaut/screens/settings_screen.dart';
import 'package:junior_astronaut/services/game_controller.dart';

const Map<String, Size> sizes = {
  'desktop browser': Size(1280, 720),
  'phone landscape': Size(844, 390),
  'narrow browser': Size(420, 860),
};

Map<String, dynamic> missionJson({int day = 3, String status = 'active', String alert = 'storm'}) => {
      'id': '11111111-2222-4333-8444-555555555555',
      'mission_status': status,
      'current_day': day,
      'total_days': 7,
      'oxygen_level': 64,
      'power_level': 22,
      'water_level': 78,
      'food_level': 60,
      'radiation_protection_level': 51,
      'score': 17,
      'alert_level': alert,
      'scenario_event_id': 'evt-1',
      'version': day,
    };

/// A controller filled with data shaped like the backend's replies; no network.
GameController fakeGame() {
  final game = GameController();
  game.phase = AppPhase.ready;
  game.config = GameConfig.fromJson(
      (jsonDecode(File('test/fixtures/game_config.json').readAsStringSync()) as Map).cast<String, dynamic>());
  game.mission = Mission.fromJson(missionJson());
  game.bestScore = 126;
  game.weather = SpaceWeather.fromJson({
    'data_status': 'live',
    'retrieved_at': '2026-11-14T07:01:15+00:00',
    'events': [
      {
        'id': 'evt-1',
        'event_type': 'GST',
        'event_date': '2026-11-12T18:00:00+00:00',
        'summary': {
          'title': 'Geomagnetic storm',
          'details': {'max_kp_index': 6.0},
          'link': 'https://example.test/gst',
        },
      },
      {
        'id': 'evt-2',
        'event_type': 'CME',
        'event_date': '2026-11-13T21:24:00+00:00',
        'summary': {
          'title': 'Coronal mass ejection',
          'details': {'speed_km_s': 474.0},
          'link': null,
        },
      },
    ],
    'game_scenario': {'alert_level': 'storm', 'basis_event_id': 'evt-1'},
  });
  return game;
}

Future<void> show(WidgetTester tester, Size size, GameController game, Widget screen) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GameScope(controller: game, child: MaterialApp(home: screen)));
  await tester.pump(const Duration(milliseconds: 600));
  expect(tester.takeException(), isNull);
}

DecisionResult fakeResult({String? result}) {
  return DecisionResult(
    Mission.fromJson(missionJson(day: 4, status: result ?? 'active')),
    Outcome.fromJson({
      'decision_effects': {'radiation_protection_level': -25, 'food_level': 4, 'score': 0},
      'daily_drain': {'oxygen_level': 6, 'power_level': 5, 'water_level': 5, 'food_level': 5},
      'resource_changes': {
        'oxygen_level': -6,
        'power_level': -5,
        'water_level': -5,
        'food_level': -1,
        'radiation_protection_level': -33,
      },
      'balance_bonus': result == null,
      'score_change': 0,
      'day_played': 3,
      'result': result,
      'feedback': 'Working on keeps the mission moving, but it wears down your protection. '
          'Careful: radiation protection is getting low.',
    }),
  );
}

void main() {
  sizes.forEach((name, size) {
    group(name, () {
      testWidgets('menu, astronaut and briefing screens', (tester) async {
        final game = fakeGame();
        await show(tester, size, game, const HomeScreen());
        expect(find.text('Continue Mission'), findsOneWidget);
        await show(tester, size, game, const AstronautScreen());
        expect(find.text('Emma'), findsOneWidget);
        await show(tester, size, game, const BriefingScreen());
        await show(tester, size, game, const NameScreen());
        expect(find.text('What is your name?'), findsOneWidget);
      });

      testWidgets('mission hub shows resources, NASA event and mission cards', (tester) async {
        final game = fakeGame();
        await show(tester, size, game, const HubScreen());
        expect(find.textContaining('Real NASA report: Geomagnetic storm on 12 Nov 2026'), findsOneWidget);
        expect(find.textContaining('SOLAR STORM'), findsOneWidget);
        expect(find.text('22%'), findsOneWidget);
        expect(find.text('Start Mission 3'), findsOneWidget);
      });

      testWidgets('mission briefing then the three choices', (tester) async {
        final game = fakeGame();
        final info = game.missionInfo(3)!;
        await show(tester, size, game, MissionScreen(info: info));
        expect(find.text('Objectives:'), findsOneWidget);
        await tester.ensureVisible(find.text('Start Mission'));
        await tester.tap(find.text('Start Mission'));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
        expect(find.text('Choose'), findsNWidgets(3));
        expect(find.text('Keep working outside'), findsOneWidget);
        expect(find.textContaining('Storm warning'), findsOneWidget);
      });

      testWidgets('result and end screens', (tester) async {
        final game = fakeGame();
        final info = game.missionInfo(3)!;
        final option = info.options.last;
        await show(tester, size, game, OutcomeScreen(info: info, option: option, result: fakeResult()));
        expect(find.text('Next Day'), findsOneWidget);
        await show(tester, size, game,
            OutcomeScreen(info: info, option: option, result: fakeResult(result: 'failed')));
        expect(find.text('Final Report'), findsOneWidget);
        await show(tester, size, game, const EndScreen(won: true, score: 126));
        expect(find.text('Congratulations!'), findsOneWidget);
        await show(tester, size, game, const EndScreen(won: false, score: 40));
        expect(find.text('Game Over'), findsOneWidget);
      });

      testWidgets('learning center and settings', (tester) async {
        final game = fakeGame();
        await show(tester, size, game, const LearningScreen());
        expect(find.textContaining('384,000'), findsOneWidget);
        await tester.ensureVisible(find.text('Space Weather Now'));
        await tester.tap(find.text('Space Weather Now'));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Speed: 474 km per second'), findsOneWidget);
        await show(tester, size, game, const SettingsScreen());
        expect(find.textContaining('Not signed in yet'), findsOneWidget);
      });
    });
  });
}
