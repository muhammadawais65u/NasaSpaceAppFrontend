import 'package:flutter/material.dart';

import '../game/mission_days.dart';
import '../models.dart';
import '../services/game_controller.dart';
import '../widgets/ui.dart';
import 'game_screen.dart';

/// One briefing screen reused for every day: tagline, cinematic story,
/// objectives with their interaction icons, the environment and a Start
/// button that launches the playable GameScreen.
class DayBriefingScreen extends StatelessWidget {
  const DayBriefingScreen({super.key, required this.info});

  final MissionInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = themeForDay(info.day);
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/mission_${info.day}.jpg', fit: BoxFit.cover),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xF2070B18), Color(0xBB070B18), Color(0x66070B18)],
              ),
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RoundIconButton(
                            icon: Icons.arrow_back, tooltip: 'Mission map', onPressed: () => Navigator.of(context).pop()),
                        const SizedBox(height: 10),
                        Text('DAY ${info.day}',
                            style: TextStyle(
                                color: theme.accent, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 3)),
                        Text(info.title.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                        Text(theme.tagline,
                            style: TextStyle(color: theme.accent, fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        GlassPanel(
                          borderColor: theme.accent,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Icon(Icons.podcasts_rounded, color: Color(0xFF45E6FF), size: 18),
                                  SizedBox(width: 8),
                                  Text('MISSION CONTROL',
                                      style: TextStyle(
                                          color: Color(0xFF45E6FF),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.6)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(theme.story, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.45)),
                              const SizedBox(height: 10),
                              Text('YOUR JOBS',
                                  style: TextStyle(
                                      color: theme.accent, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.6)),
                              const SizedBox(height: 4),
                              for (var i = 0; i < info.objectives.length; i++)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    children: [
                                      Icon(theme.kindOf(i).icon, color: theme.accent, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(info.objectives[i],
                                            style: const TextStyle(
                                                color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.terrain_rounded, color: Color(0xFFB9C6F2), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(theme.environment,
                                        style: const TextStyle(color: Color(0xFFB9C6F2), fontSize: 13.5, height: 1.35)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const _NasaReport(),
                        const SizedBox(height: 14),
                        GameButton(
                          label: 'Start Day ${info.day}',
                          icon: Icons.rocket_launch,
                          color: GameColors.yellow,
                          big: true,
                          onPressed: () => Navigator.of(context)
                              .pushReplacement(MaterialPageRoute<void>(builder: (_) => GameScreen(info: info))),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(flex: 4, child: _AstronautSide(info: info, accent: theme.accent)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The real NASA space-weather report behind this mission's alert, when we
/// have one. Never invent data: no weather loaded -> no panel.
class _NasaReport extends StatelessWidget {
  const _NasaReport();

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final w = game.weather;
    if (w == null) return const SizedBox.shrink();
    final e = game.scenarioEvent;
    final level = (game.mission?.alertLevel ?? w.alertLevel).toUpperCase();
    final color =
        level == 'STORM' ? GameColors.red : (level == 'WATCH' ? GameColors.yellow : const Color(0xFF45E6FF));
    return GlassPanel(
      borderColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.satellite_alt_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  e != null
                      ? 'NASA really saw this: ${e.title}'
                          '${e.date == null ? '' : ' on ${formatDate(e.date!)}'}. Game alert: $level.'
                      : level == 'CALM'
                          ? 'NASA DONKI shows a quiet Sun right now. Game alert: CALM.'
                          : 'Game alert: $level - based on NASA DONKI space-weather data.',
                  style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          DataBadge(status: w.dataStatus, source: 'NASA DONKI', retrievedAt: w.retrievedAt),
        ],
      ),
    );
  }
}

class _AstronautSide extends StatelessWidget {
  const _AstronautSide({required this.info, required this.accent});

  final MissionInfo info;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AstronautAvatar(id: game.astronaut, size: 100, ring: accent),
          const SizedBox(height: 8),
          Text('Astronaut ${AstronautAvatar.displayName(game.astronaut)}',
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(info.scenario,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB9C6F2), fontSize: 14, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
