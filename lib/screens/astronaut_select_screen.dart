import 'package:flutter/material.dart';

import '../game/mission_days.dart';
import '../models.dart';
import '../services/game_controller.dart';
import '../widgets/ui.dart';
import 'mission_map_screen.dart';

/// Pick your astronaut: suit portrait, suit accent colour, name and a
/// preview. The choice stays consistent through all seven days.
class AstronautSelectScreen extends StatefulWidget {
  const AstronautSelectScreen({super.key});

  static const Map<String, String> bios = {
    'alex': 'Explorer class. Loves long rover rides and crater walks.',
    'emma': 'Engineer class. Can fix almost anything with spare parts.',
    'noah': 'Science class. Studies Moon rocks and sends data to Earth.',
  };

  @override
  State<AstronautSelectScreen> createState() => _AstronautSelectScreenState();
}

class _AstronautSelectScreenState extends State<AstronautSelectScreen> {
  String? _selected;
  bool _busy = false;

  Future<void> _confirm() async {
    final game = GameScope.of(context);
    final id = _selected ?? game.astronaut;
    setState(() => _busy = true);
    await game.setAstronaut(id);
    try {
      if (!game.hasActiveMission) await game.startMission();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, 'Mission Control', e.message);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const MissionMapScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final selected = _selected ?? game.astronaut;
    final accent = suitAccentFor(selected);
    return SpaceBackground(
      child: Column(
        children: [
          Row(
            children: [
              RoundIconButton(icon: Icons.arrow_back, tooltip: 'Back', onPressed: () => Navigator.of(context).pop()),
              const Expanded(child: Center(child: TitleBanner('Select Your Astronaut'))),
              const SizedBox(width: 46),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Preview.
                    AstronautAvatar(id: selected, size: 96, ring: accent),
                    const SizedBox(height: 8),
                    Text(AstronautAvatar.displayName(selected).toUpperCase(),
                        style: TextStyle(color: accent, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    Text(AstronautSelectScreen.bios[selected] ?? '',
                        style: const TextStyle(color: Color(0xFFB9C6F2), fontSize: 14)),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 18,
                      runSpacing: 18,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final id in GameController.astronauts)
                          _SuitCard(id: id, selected: id == selected, onTap: () => setState(() => _selected = id)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GameButton(
              label: 'Select Astronaut',
              icon: Icons.check_rounded,
              color: GameColors.yellow,
              big: true,
              busy: _busy,
              onPressed: _confirm,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuitCard extends StatelessWidget {
  const _SuitCard({required this.id, required this.selected, required this.onTap});

  final String id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = suitAccentFor(id);
    final border = selected ? accent : GameColors.panelBorder;
    return Material(
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
            border: Border.all(color: border, width: selected ? 4 : 2),
            boxShadow: [BoxShadow(color: border.withAlpha(selected ? 160 : 50), blurRadius: selected ? 24 : 8)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(AstronautAvatar.asset(id), width: 120, height: 160, fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(AstronautAvatar.displayName(id),
                        style: TextStyle(color: selected ? accent : Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
