import 'package:flutter/material.dart';

import '../game/mission_days.dart';
import '../models.dart';
import '../services/game_controller.dart';
import '../widgets/ui.dart';
import 'day_briefing_screen.dart';
import 'final_ending_screen.dart';
import 'hub_screen.dart';

/// Mission briefing first, then the three choices with their trade-offs.
class MissionScreen extends StatefulWidget {
  const MissionScreen({super.key, required this.info});

  final MissionInfo info;

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  bool _choosing = false;
  String? _busyOption;

  Future<void> _choose(DecisionOption option) async {
    final game = GameScope.of(context);
    setState(() => _busyOption = option.id);
    try {
      final result = await game.decide(widget.info, option);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => OutcomeScreen(info: widget.info, option: option, result: result),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busyOption = null);
      await showMessage(context, 'Mission Control', e.message);
      if (!mounted) return;
      if (e.code == 'version_conflict' || e.code == 'mission_not_active') {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return SpaceBackground(
      image: 'assets/images/mission_${info.day}.jpg',
      child: Column(
        children: [
          Row(
            children: [
              RoundIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                onPressed: () {
                  if (_busyOption != null) return;
                  if (_choosing) {
                    setState(() => _choosing = false);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
              Expanded(child: Center(child: TitleBanner('Mission ${info.day}: ${info.title}'))),
              const SizedBox(width: 46),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: _choosing ? _choices(context) : _briefing(context)),
        ],
      ),
    );
  }

  Widget _briefing(BuildContext context) {
    final info = widget.info;
    var best = 0;
    for (final o in info.options) {
      final s = o.effects['score'] ?? 0;
      if (s > best) best = s;
    }
    final picture = Tilt3D(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.asset('assets/images/mission_${info.day}.jpg',
            width: 320, height: 220, fit: BoxFit.cover, semanticLabel: info.title),
      ),
    );
    final details = GlassPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(info.description, style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.3)),
          const SizedBox(height: 10),
          const Text('Objectives:',
              style: TextStyle(color: GameColors.yellow, fontSize: 17, fontWeight: FontWeight.w900)),
          for (final o in info.objectives)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: GameColors.yellow, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(o,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text('Reward: up to +$best points',
              style: const TextStyle(color: GameColors.yellow, fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    );
    final start = GameButton(
      label: 'Start Mission',
      icon: Icons.rocket_launch,
      color: GameColors.yellow,
      big: true,
      onPressed: () => setState(() => _choosing = true),
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= 720) {
          return Row(
            children: [
              Expanded(child: Center(child: picture)),
              const SizedBox(width: 16),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [details, const SizedBox(height: 14), start],
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return SingleChildScrollView(
          child: Column(
            children: [picture, const SizedBox(height: 12), details, const SizedBox(height: 14), start],
          ),
        );
      },
    );
  }

  Widget _choices(BuildContext context) {
    final game = GameScope.of(context);
    final info = widget.info;
    final mission = game.mission;
    final storm = mission != null && mission.alertLevel == 'storm';
    final radiationDay = info.decisionType == 'radiation_response';
    final event = game.scenarioEvent;
    return SingleChildScrollView(
      child: Column(
        children: [
          GlassPanel(
            borderColor: info.decisionType == 'emergency_response' ? GameColors.red : null,
            child: Row(
              children: [
                AstronautAvatar(id: game.astronaut, size: 58),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(info.scenario,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      const Text('What should we do? Every choice has a cost.',
                          style: TextStyle(color: GameColors.textDim, fontSize: 14)),
                      if (radiationDay && mission != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          event != null
                              ? 'NASA really saw this: ${event.title}'
                                  '${event.date == null ? '' : ' on ${formatDate(event.date!)}'}. '
                                  'In our game the alert is ${mission.alertLevel.toUpperCase()}.'
                              : 'Game alert level: ${mission.alertLevel.toUpperCase()}.',
                          style: const TextStyle(color: GameColors.yellow, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        if (storm)
                          const Text('Storm warning: working outside will cost extra shield and points!',
                              style: TextStyle(color: GameColors.red, fontSize: 14, fontWeight: FontWeight.w800)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              for (final option in info.options)
                _OptionCard(
                  option: option,
                  busy: _busyOption == option.id,
                  enabled: _busyOption == null,
                  onChoose: () => _choose(option),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (game.config != null) _DailyUse(drain: game.config!.dailyDrain),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.option, required this.busy, required this.enabled, required this.onChoose});

  final DecisionOption option;
  final bool busy;
  final bool enabled;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: GlassPanel(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(option.label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            EffectChips(effects: option.effects),
            const SizedBox(height: 10),
            GameButton(label: 'Choose', busy: busy, onPressed: enabled ? onChoose : null),
          ],
        ),
      ),
    );
  }
}

class _DailyUse extends StatelessWidget {
  const _DailyUse({required this.drain});

  final Map<String, int> drain;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('The base also uses this much every day:',
            style: TextStyle(color: GameColors.textDim, fontSize: 13)),
        const SizedBox(height: 4),
        EffectChips(effects: {for (final e in drain.entries) e.key: -e.value}),
        const SizedBox(height: 4),
        const Text('Game numbers are simplified. They are not NASA measurements.',
            style: TextStyle(color: GameColors.textDim, fontSize: 12)),
      ],
    );
  }
}

/// What happened after a choice: resource changes, points and the lesson.
class OutcomeScreen extends StatelessWidget {
  const OutcomeScreen({super.key, required this.info, required this.option, required this.result});

  final MissionInfo info;
  final DecisionOption option;
  final DecisionResult result;

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final outcome = result.outcome;
    final mission = result.mission;
    final ended = outcome.result != null;
    final failed = outcome.result == 'failed';
    final theme = themeForDay(info.day);
    return SpaceBackground(
      maxWidth: 820,
      image: 'assets/images/mission_${info.day}.jpg',
      child: Column(
        children: [
          TitleBanner(
            failed ? 'Oh no!' : 'Day ${info.day} Complete!',
            color: failed ? GameColors.red : theme.accent,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: GlassPanel(
                  borderColor: failed ? GameColors.red : theme.accent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          AstronautAvatar(id: game.astronaut, size: 54, ring: failed ? GameColors.red : GameColors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!failed)
                                  Text(theme.ending,
                                      style: const TextStyle(
                                          color: GameColors.yellow, fontSize: 16, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(outcome.feedback,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, height: 1.3)),
                                const SizedBox(height: 4),
                                Text(
                                  'Astronaut status: ${failed ? 'Emergency' : 'Safe'} · Objectives completed: ${info.objectives.length}/${info.objectives.length}',
                                  style: TextStyle(
                                      color: failed ? GameColors.red : GameColors.green,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          for (var i = 0; i < info.objectives.length; i++)
                            _ObjectiveDone(objective: info.objectives[i], icon: theme.kindOf(i).icon),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (final key in resourceKeys)
                        ResourceBar(
                          resource: key,
                          value: mission.levels[key] ?? 0,
                          change: outcome.resourceChanges[key],
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          _Pill(
                            icon: Icons.star_rounded,
                            text: 'Points ${outcome.scoreChange >= 0 ? '+' : ''}${outcome.scoreChange}',
                            color: GameColors.yellow,
                          ),
                          if (outcome.balanceBonus)
                            const _Pill(
                              icon: Icons.balance,
                              text: 'Balance bonus: every system is above 30%',
                              color: GameColors.green,
                            ),
                          _Pill(icon: Icons.emoji_events, text: 'Score ${mission.score}', color: GameColors.panelBorder),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('The changes include what the base uses every day.',
                          style: TextStyle(color: GameColors.textDim, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GameButton(
            label: ended ? 'Final Report' : 'Next Day',
            icon: ended ? Icons.emoji_events : Icons.arrow_forward,
            big: true,
            onPressed: () {
              if (!ended) {
                final next = game.missionInfo(mission.currentDay);
                if (next != null) {
                  Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(builder: (_) => DayBriefingScreen(info: next)));
                } else {
                  Navigator.of(context).pop();
                }
                return;
              }
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => FinalEndingScreen(won: !failed, score: mission.score)),
                (route) => route.isFirst,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One finished objective on the outcome screen.
class _ObjectiveDone extends StatelessWidget {
  const _ObjectiveDone({required this.objective, required this.icon});

  final String objective;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: GameColors.green.withAlpha(30),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: GameColors.green, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: GameColors.green, size: 15),
          const SizedBox(width: 5),
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(objective, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

/// "Congratulations!" after 7 missions, or "Game Over" when a resource ran out.
class EndScreen extends StatefulWidget {
  const EndScreen({super.key, required this.won, required this.score});

  final bool won;
  final int score;

  @override
  State<EndScreen> createState() => _EndScreenState();
}

class _EndScreenState extends State<EndScreen> {
  bool _busy = false;

  Future<void> _playAgain() async {
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
    final won = widget.won;
    return SpaceBackground(
      maxWidth: 640,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tilt3D(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    won ? 'assets/images/trophy.jpg' : 'assets/images/moon.jpg',
                    height: 150,
                    fit: BoxFit.cover,
                    semanticLabel: won ? 'A golden trophy' : 'The Moon',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TitleBanner(won ? 'Congratulations!' : 'Game Over', color: won ? GameColors.blue : GameColors.red),
              const SizedBox(height: 8),
              Text(
                won ? 'You are a True Space Hero!' : 'Don\'t worry! Try again!',
                style: const TextStyle(color: GameColors.yellow, fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                won
                    ? 'You kept the whole crew safe for 7 missions.'
                    : 'Real mission planners practise many times too. Which system ran out?',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 12),
              GlassPanel(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AstronautAvatar(id: game.astronaut, size: 56),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Your Score:  ${widget.score}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                          Text('Best Score:  ${game.bestScore}',
                              style: const TextStyle(
                                  color: GameColors.yellow, fontSize: 20, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  GameButton(
                    label: won ? 'Play Again' : 'Try Again',
                    icon: Icons.replay,
                    busy: _busy,
                    onPressed: _playAgain,
                  ),
                  GameButton(
                    label: 'Main Menu',
                    icon: Icons.home,
                    color: GameColors.blue,
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
