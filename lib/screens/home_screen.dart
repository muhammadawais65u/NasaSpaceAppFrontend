import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/game_controller.dart';
import '../widgets/ui.dart';
import 'hub_screen.dart';
import 'learning_screen.dart';
import 'name_screen.dart';
import 'settings_screen.dart';

void pushScreen(BuildContext context, Widget screen) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    return SpaceBackground(
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 640;
          final heroHeight = math.min(wide ? box.maxHeight * 0.9 : 260.0, 480.0);
          final hero = Tilt3D(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                'assets/images/hero.jpg',
                height: heroHeight,
                fit: BoxFit.cover,
                semanticLabel: 'A smiling astronaut standing on the Moon',
              ),
            ),
          );
          final menu = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Logo(),
              const SizedBox(height: 18),
              SizedBox(
                width: 280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GameButton(
                      label: game.hasActiveMission ? 'Continue Mission' : 'Start Mission',
                      icon: Icons.play_arrow_rounded,
                      big: true,
                      onPressed: () => pushScreen(
                        context,
                        !game.signedIn
                            ? const NameScreen()
                            : game.hasActiveMission
                                ? const HubScreen()
                                : const AstronautScreen(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GameButton(
                      label: 'How to Play',
                      icon: Icons.help_outline,
                      color: GameColors.blue,
                      onPressed: () => showHowToPlay(context),
                    ),
                    const SizedBox(height: 10),
                    GameButton(
                      label: 'Learning Center',
                      icon: Icons.menu_book_rounded,
                      color: GameColors.blue,
                      onPressed: () => pushScreen(context, const LearningScreen()),
                    ),
                    const SizedBox(height: 10),
                    GameButton(
                      label: 'Settings',
                      icon: Icons.settings,
                      color: GameColors.blue,
                      onPressed: () => pushScreen(context, const SettingsScreen()),
                    ),
                  ],
                ),
              ),
              if (game.signedIn && game.playerName.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Welcome back, ${game.playerName}!',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              ],
              if (game.bestScore > 0) ...[
                const SizedBox(height: 4),
                Text('Best score: ${game.bestScore}',
                    style: const TextStyle(color: GameColors.yellow, fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ],
          );
          if (wide) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                hero,
                Flexible(child: SingleChildScrollView(child: menu)),
              ],
            );
          }
          return SingleChildScrollView(
            child: Column(children: [menu, const SizedBox(height: 16), hero]),
          );
        },
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    const shadow = [Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 3))];
    return Semantics(
      header: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('JUNIOR ASTRONAUT',
                style: TextStyle(
                    color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 1, shadows: shadow)),
          ),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('MISSION TRAINER',
                style: TextStyle(
                    color: GameColors.yellow,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    shadows: shadow)),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            decoration: BoxDecoration(
              color: GameColors.blue,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white70, width: 1.5),
            ),
            child: const Text('Moon Outpost',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

Future<void> showHowToPlay(BuildContext context) {
  const steps = [
    'You are in charge of a Moon base for 7 missions.',
    'Each mission, pick one of three choices.',
    'Every choice helps something and costs something else. Look at the green and red numbers!',
    'Keep Oxygen, Power, Water, Food and Shield above zero.',
    'The storm alert comes from real NASA reports about the Sun.',
  ];
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: GlassPanel(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TitleBanner('How to Play'),
                const SizedBox(height: 12),
                for (var i = 0; i < steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: GameColors.yellow,
                          child: Text('${i + 1}',
                              style: const TextStyle(color: Color(0xFF3A2500), fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(steps[i], style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.3)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                GameButton(label: 'Got it!', onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AstronautScreen extends StatefulWidget {
  const AstronautScreen({super.key});

  @override
  State<AstronautScreen> createState() => _AstronautScreenState();
}

class _AstronautScreenState extends State<AstronautScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final selected = _selected ?? game.astronaut;
    return SpaceBackground(
      child: Column(
        children: [
          Row(
            children: [
              RoundIconButton(
                  icon: Icons.arrow_back, tooltip: 'Back', onPressed: () => Navigator.of(context).pop()),
              const Expanded(child: Center(child: TitleBanner('Select Your Astronaut'))),
              const SizedBox(width: 46),
            ],
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final id in GameController.astronauts)
                      _AstronautCard(id: id, selected: id == selected, onTap: () => setState(() => _selected = id)),
                  ],
                ),
              ),
            ),
          ),
          GameButton(
            label: 'Select',
            big: true,
            onPressed: () {
              game.setAstronaut(selected);
              Navigator.of(context)
                  .pushReplacement(MaterialPageRoute<void>(builder: (_) => const BriefingScreen()));
            },
          ),
        ],
      ),
    );
  }
}

class _AstronautCard extends StatelessWidget {
  const _AstronautCard({required this.id, required this.selected, required this.onTap});

  final String id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = AstronautAvatar.displayName(id);
    final color = selected ? GameColors.yellow : GameColors.panelBorder;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Astronaut $name',
      child: Tilt3D(
        float: selected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: GameColors.panel,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color, width: selected ? 4 : 2),
                boxShadow: [BoxShadow(color: color.withAlpha(selected ? 150 : 50), blurRadius: selected ? 22 : 8)],
              ),
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(AstronautAvatar.asset(id), width: 130, height: 175, fit: BoxFit.cover),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(name,
                          style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
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

class BriefingScreen extends StatefulWidget {
  const BriefingScreen({super.key});

  @override
  State<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends State<BriefingScreen> {
  bool _busy = false;

  Future<void> _start() async {
    final game = GameScope.of(context);
    setState(() => _busy = true);
    try {
      await game.startMission();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const HubScreen()));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, 'Mission Control', e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    const goals = [
      'Build your Moon Outpost',
      'Keep the power on',
      'Stay safe from the Sun\'s radiation',
      'Look after water, air and food',
      'Explore and do science',
    ];
    return SpaceBackground(
      maxWidth: 760,
      child: Column(
        children: [
          Row(
            children: [
              RoundIconButton(
                  icon: Icons.arrow_back, tooltip: 'Back', onPressed: () => Navigator.of(context).pop()),
              const Expanded(child: Center(child: TitleBanner('Mission Briefing'))),
              AstronautAvatar(id: game.astronaut, size: 46),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: GlassPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome, ${game.playerName.isEmpty ? 'Junior Astronaut' : game.playerName}!',
                          style: const TextStyle(color: GameColors.yellow, fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      const Text('Our mission is to run a Moon Outpost for 7 missions. You will:',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 8),
                      for (final g in goals)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: GameColors.green, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(g,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'Remember: every choice helps one thing and costs another. That is called a trade-off.',
                        style: TextStyle(color: GameColors.textDim, fontSize: 15, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GameButton(
            label: 'Let\'s Go!',
            icon: Icons.rocket_launch,
            color: GameColors.yellow,
            big: true,
            busy: _busy,
            onPressed: _start,
          ),
        ],
      ),
    );
  }
}
