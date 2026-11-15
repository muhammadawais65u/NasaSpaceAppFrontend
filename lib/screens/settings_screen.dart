import 'package:flutter/material.dart';

import '../config.dart';
import '../services/game_controller.dart';
import '../widgets/ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final account = !game.signedIn
        ? 'Not signed in yet. Press Start Mission and type your name.'
        : 'Playing as ${game.playerName.isEmpty ? 'Junior Astronaut' : game.playerName}';
    return SpaceBackground(
      maxWidth: 720,
      child: Column(
        children: [
          Row(
            children: [
              RoundIconButton(
                  icon: Icons.arrow_back, tooltip: 'Back', onPressed: () => Navigator.of(context).pop()),
              const Expanded(child: Center(child: TitleBanner('Settings'))),
              const SizedBox(width: 46),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Heading('Your astronaut'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 14,
                          runSpacing: 10,
                          children: [
                            for (final id in GameController.astronauts)
                              Semantics(
                                button: true,
                                selected: id == game.astronaut,
                                label: 'Choose astronaut ${AstronautAvatar.displayName(id)}',
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => game.setAstronaut(id),
                                  child: ExcludeSemantics(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AstronautAvatar(
                                          id: id,
                                          size: 72,
                                          ring: id == game.astronaut ? GameColors.yellow : GameColors.panelBorder,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(AstronautAvatar.displayName(id),
                                            style: TextStyle(
                                                color: id == game.astronaut ? GameColors.yellow : Colors.white,
                                                fontWeight: FontWeight.w800)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Heading('Player'),
                        const SizedBox(height: 6),
                        Text(account, style: const TextStyle(color: Colors.white, fontSize: 16)),
                        const SizedBox(height: 4),
                        const Text('Your missions are saved after every choice.',
                            style: TextStyle(color: GameColors.textDim, fontSize: 14)),
                        const SizedBox(height: 10),
                        if (game.signedIn)
                          GameButton(
                            label: 'Start as a New Player',
                            icon: Icons.logout,
                            color: GameColors.red,
                            onPressed: () => _confirmSignOut(context, game),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Heading('Where the science comes from'),
                        SizedBox(height: 6),
                        Text(
                          'Space weather: NASA DONKI (Space Weather Database Of Notifications, Knowledge, '
                          'Information), from api.nasa.gov.\n'
                          'Space biology studies: NASA Open Science Data Repository (OSDR), osdr.nasa.gov.\n\n'
                          'The resource numbers, points and the calm / watch / storm alert are simplified '
                          'game rules. They are not NASA measurements.\n\n'
                          'This is a student project for the NASA Space Apps Challenge. '
                          'It is not affiliated with or endorsed by NASA.',
                          style: TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
                        ),
                        SizedBox(height: 8),
                        Text('Game server: ${AppConfig.apiBase}',
                            style: TextStyle(color: GameColors.textDim, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, GameController game) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF14226A),
        title: const Text('Start as a new player?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text(
          'Your saved missions and best score on this device will be gone for good.',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Start new')),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    await game.signOut();
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: GameColors.yellow, fontSize: 18, fontWeight: FontWeight.w900));
  }
}
