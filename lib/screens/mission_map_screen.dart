import 'package:flutter/material.dart';

import '../game/mission_days.dart';
import '../models.dart';
import '../services/game_controller.dart';
import '../widgets/ui.dart';
import 'day_briefing_screen.dart';
import 'menu_screen.dart';

/// The 7-day lunar mission map: a winding route with a station per mission.
/// Completed stations are green, today's glows, the rest stay locked.
class MissionMapScreen extends StatelessWidget {
  const MissionMapScreen({super.key});

  // Node positions along the route, as fractions of the map size.
  static const List<Offset> _route = [
    Offset(0.08, 0.78),
    Offset(0.24, 0.55),
    Offset(0.38, 0.74),
    Offset(0.52, 0.48),
    Offset(0.64, 0.68),
    Offset(0.78, 0.40),
    Offset(0.90, 0.58),
  ];

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final mission = game.mission;
    final config = game.config;
    if (mission == null || config == null || !mission.isActive) {
      return SpaceBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No mission is running yet.',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              GameButton(
                  label: 'Main Menu',
                  icon: Icons.home,
                  color: GameColors.blue,
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute<void>(builder: (_) => const MenuScreen()), (r) => r.isFirst)),
            ],
          ),
        ),
      );
    }
    final currentDay = mission.currentDay;
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/moon.jpg', fit: BoxFit.cover),
          Container(color: const Color(0xCC070B18)),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    RoundIconButton(
                        icon: Icons.home, tooltip: 'Main menu', onPressed: () => Navigator.of(context).pop()),
                    const Expanded(child: Center(child: TitleBanner('7-Day Mission Map'))),
                    AstronautAvatar(id: game.astronaut, size: 44),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: LayoutBuilder(
                      builder: (context, box) => Stack(
                        children: [
                          CustomPaint(
                            size: box.biggest,
                            painter: _RoutePainter(route: _route, currentDay: currentDay, total: config.missions.length),
                          ),
                          for (var i = 0; i < config.missions.length; i++)
                            Positioned(
                              left: _route[i].dx * box.maxWidth - 62,
                              top: _route[i].dy * box.maxHeight - 52,
                              width: 124,
                              child: _MapNode(
                                info: config.missions[i],
                                state: config.missions[i].day < currentDay
                                    ? _NodeState.done
                                    : config.missions[i].day == currentDay
                                        ? _NodeState.current
                                        : _NodeState.locked,
                                onTap: () {
                                  if (config.missions[i].day > currentDay) {
                                    showMessage(context, 'Locked',
                                        'Finish Day $currentDay first. The colony is built one day at a time!');
                                    return;
                                  }
                                  Navigator.of(context).push(MaterialPageRoute<void>(
                                    builder: (_) => DayBriefingScreen(info: config.missions[i]),
                                  ));
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('Day ${currentDay.clamp(1, mission.totalDays)} of ${mission.totalDays} · Score ${mission.score}',
                      style: const TextStyle(color: Color(0xFFB9C6F2), fontSize: 14, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _NodeState { done, current, locked }

class _MapNode extends StatelessWidget {
  const _MapNode({required this.info, required this.state, required this.onTap});

  final MissionInfo info;
  final _NodeState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = themeForDay(info.day).accent;
    final locked = state == _NodeState.locked;
    final color = state == _NodeState.done
        ? GameColors.green
        : locked
            ? const Color(0xFF6B7399)
            : accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Opacity(
          opacity: locked ? 0.55 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xE6101C52),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color, width: state == _NodeState.current ? 3 : 1.5),
              boxShadow: [
                if (state == _NodeState.current) BoxShadow(color: accent.withAlpha(140), blurRadius: 18),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset('assets/images/mission_${info.day}.jpg', height: 52, width: 108, fit: BoxFit.cover),
                ),
                const SizedBox(height: 3),
                Text('DAY ${info.day}',
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                Text(info.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, height: 1.1)),
                Icon(
                  state == _NodeState.done
                      ? Icons.check_circle
                      : locked
                          ? Icons.lock
                          : Icons.play_circle_fill,
                  color: color,
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The winding route between stations; the finished part is brighter.
class _RoutePainter extends CustomPainter {
  const _RoutePainter({required this.route, required this.currentDay, required this.total});

  final List<Offset> route;
  final int currentDay;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    Offset pt(Offset f) => Offset(f.dx * size.width, f.dy * size.height);
    final full = Path()..moveTo(pt(route.first).dx, pt(route.first).dy);
    final done = Path()..moveTo(pt(route.first).dx, pt(route.first).dy);
    for (var i = 1; i < route.length; i++) {
      final a = pt(route[i - 1]);
      final b = pt(route[i]);
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2 - 18);
      full.quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
      if (i < currentDay) done.quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
    }
    canvas.drawPath(
      full,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x556B7399),
    );
    canvas.drawPath(
      done,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF45E6FF),
    );
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) => oldDelegate.currentDay != currentDay;
}
