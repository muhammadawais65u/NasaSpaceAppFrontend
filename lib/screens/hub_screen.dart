import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/game_controller.dart';
import '../widgets/ui.dart';
import 'game_screen.dart';

/// "Choose Your Mission": resources, the NASA-based alert and a 3D card carousel.
class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  PageController? _pages;
  double _fraction = 0;
  int _shownDay = 0;

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  PageController _controllerFor(double width, int day) {
    final fraction = (210 / width).clamp(0.22, 0.8).toDouble();
    final old = _pages;
    if (old == null || (fraction - _fraction).abs() > 0.01) {
      _pages = PageController(viewportFraction: fraction, initialPage: day - 1);
      _fraction = fraction;
      _shownDay = day;
      if (old != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
    } else if (day != _shownDay) {
      // A mission was just played: slide to the next one.
      _shownDay = day;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && old.hasClients) {
          old.animateToPage(day - 1, duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
        }
      });
    }
    return _pages!;
  }

  void _open(MissionInfo info) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GameScreen(info: info)));
  }

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final mission = game.mission;
    final config = game.config;
    if (mission == null || config == null || !mission.isActive) {
      return SpaceBackground(
        child: Center(
          child: GameButton(
            label: 'Main Menu',
            icon: Icons.home,
            color: GameColors.blue,
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ),
      );
    }
    final current = game.missionInfo(mission.currentDay);
    return SpaceBackground(
      image: 'assets/images/base.jpg',
      child: Column(
        children: [
          _TopBar(mission: mission, astronaut: game.astronaut),
          const SizedBox(height: 8),
          _AlertBanner(mission: mission, event: game.scenarioEvent, weather: game.weather),
          const SizedBox(height: 6),
          const TitleBanner('Choose Your Mission'),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final pages = _controllerFor(box.maxWidth, mission.currentDay);
                return Row(
                  children: [
                    RoundIconButton(
                      icon: Icons.chevron_left,
                      tooltip: 'Previous mission',
                      onPressed: () => pages.previousPage(
                          duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: pages,
                        itemCount: config.missions.length,
                        scrollBehavior: const MaterialScrollBehavior().copyWith(dragDevices: {
                          PointerDeviceKind.touch,
                          PointerDeviceKind.mouse,
                          PointerDeviceKind.trackpad,
                          PointerDeviceKind.stylus,
                        }),
                        itemBuilder: (context, index) {
                          final info = config.missions[index];
                          final state = info.day < mission.currentDay
                              ? _CardState.done
                              : info.day == mission.currentDay
                                  ? _CardState.ready
                                  : _CardState.locked;
                          return _Carousel3D(
                            controller: pages,
                            index: index,
                            initialPage: mission.currentDay - 1,
                            child: _MissionCard(
                              info: info,
                              state: state,
                              onTap: () {
                                if (state == _CardState.ready) {
                                  _open(info);
                                } else {
                                  pages.animateToPage(index,
                                      duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    RoundIconButton(
                      icon: Icons.chevron_right,
                      tooltip: 'Next mission',
                      onPressed: () =>
                          pages.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          if (current != null)
            GameButton(
              label: 'Start Mission ${current.day}',
              icon: Icons.rocket_launch,
              color: GameColors.yellow,
              big: true,
              onPressed: () => _open(current),
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.mission, required this.astronaut});

  final Mission mission;
  final String astronaut;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RoundIconButton(
          icon: Icons.home,
          tooltip: 'Main menu',
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final key in resourceKeys) ResourceChip(resource: key, value: mission.levels[key] ?? 0),
              _InfoChip(
                icon: Icons.flag_rounded,
                label: 'Missions',
                value: '${mission.currentDay - 1} / ${mission.totalDays}',
              ),
              _InfoChip(icon: Icons.star_rounded, label: 'Score', value: '${mission.score}'),
            ],
          ),
        ),
        const SizedBox(width: 8),
        AstronautAvatar(id: astronaut, size: 46),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xCC0A1238),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GameColors.yellow, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: GameColors.yellow, size: 22),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  Text(value,
                      style: const TextStyle(color: GameColors.yellow, fontSize: 15, fontWeight: FontWeight.w900)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Real NASA observation on one line, game simulation on the other. Never mixed.
class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.mission, required this.event, required this.weather});

  final Mission mission;
  final SpaceEvent? event;
  final SpaceWeather? weather;

  @override
  Widget build(BuildContext context) {
    final level = mission.alertLevel;
    final Color color;
    final IconData icon;
    final String game;
    switch (level) {
      case 'storm':
        color = GameColors.red;
        icon = Icons.warning_amber_rounded;
        game = 'Game alert: SOLAR STORM. Your shield wears down twice as fast.';
        break;
      case 'watch':
        color = GameColors.yellow;
        icon = Icons.wb_sunny_rounded;
        game = 'Game alert: WATCH. The Sun is active, so your shield wears down faster.';
        break;
      default:
        color = GameColors.green;
        icon = Icons.nightlight_round;
        game = 'Game alert: CALM. The Sun is quiet for this mission.';
    }

    final String source;
    final e = event;
    if (e != null) {
      final when = e.date == null ? '' : ' on ${formatDate(e.date!)}';
      source = 'Real NASA report: ${e.title}$when.';
    } else if (mission.scenarioEventId != null) {
      source = 'Based on a real NASA DONKI space-weather report.';
    } else if (level != 'calm') {
      source = 'Demo alert - not based on NASA data.';
    } else {
      source = 'NASA DONKI shows no big solar events in the last 7 days (or no data).';
    }

    final w = weather;
    return GlassPanel(
      borderColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(game, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
                Text(source, style: const TextStyle(color: Colors.white, fontSize: 13)),
                if (w != null) DataBadge(status: w.dataStatus, source: 'NASA DONKI', retrievedAt: w.retrievedAt),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _CardState { done, ready, locked }

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.info, required this.state, required this.onTap});

  final MissionInfo info;
  final _CardState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String text;
    switch (state) {
      case _CardState.done:
        color = GameColors.blue;
        icon = Icons.check_circle;
        text = 'Done';
        break;
      case _CardState.ready:
        color = GameColors.green;
        icon = Icons.play_circle_fill;
        text = 'Ready';
        break;
      case _CardState.locked:
        color = const Color(0xFF6B7399);
        icon = Icons.lock;
        text = 'Locked';
        break;
    }
    final locked = state == _CardState.locked;
    return Center(
      child: Semantics(
        button: true,
        label: 'Mission ${info.day}, ${info.title}, $text',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: ExcludeSemantics(
              child: Container(
                width: 180,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GameColors.panel,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: state == _CardState.ready ? GameColors.yellow : GameColors.panelBorder,
                      width: state == _CardState.ready ? 3 : 2),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 6))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${info.day}',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    SizedBox(
                      height: 40,
                      child: Center(
                        child: Text(info.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, height: 1.1)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Opacity(
                          opacity: locked ? 0.45 : 1,
                          child: Image.asset('assets/images/mission_${info.day}.jpg',
                              height: 100, width: 164, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, color: Colors.white, size: 16),
                          const SizedBox(width: 5),
                          Text(text,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Turns each page of the carousel in 3D depending on how far it is from the centre.
class _Carousel3D extends StatelessWidget {
  const _Carousel3D({
    required this.controller,
    required this.index,
    required this.initialPage,
    required this.child,
  });

  final PageController controller;
  final int index;
  final int initialPage;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        double page = initialPage.toDouble();
        if (controller.hasClients && controller.position.haveDimensions) {
          page = controller.page ?? page;
        }
        final delta = (index - page).clamp(-2.0, 2.0).toDouble();
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0016)
          ..rotateY(-delta * 0.5);
        return Transform(
          alignment: Alignment.center,
          transform: matrix,
          child: Transform.scale(scale: 1 - delta.abs() * 0.1, child: child),
        );
      },
    );
  }
}
