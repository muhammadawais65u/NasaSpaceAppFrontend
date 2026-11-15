import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/game_controller.dart';
import '../widgets/ui.dart';
import 'home_screen.dart';
import 'learning_screen.dart';
import 'mission_map_screen.dart';
import 'name_screen.dart';
import 'settings_screen.dart';
import 'story_screen.dart';

/// Main menu: Play, Continue, Mission Map, How to Play, Settings, Exit.
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/base.jpg', fit: BoxFit.cover),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xF2070B18), Color(0xCC070B18), Color(0x55070B18)],
              ),
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('JUNIOR ASTRONAUT',
                              style: TextStyle(
                                  color: Color(0xFF45E6FF),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 5)),
                          const Text('MOON SURVIVAL',
                              style: TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900)),
                          const Text('ADVENTURE',
                              style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 44, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text(
                            game.playerName.isEmpty
                                ? '7 days. 1 astronaut. 1 colony to save.'
                                : 'Welcome back, ${game.playerName}!',
                            style: const TextStyle(color: Color(0xFFB9C6F2), fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: 280,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                GameButton(
                                  label: 'Play Game',
                                  icon: Icons.play_arrow_rounded,
                                  color: GameColors.yellow,
                                  big: true,
                                  onPressed: () => _push(
                                    context,
                                    game.signedIn ? const StoryScreen() : const NameScreen(),
                                  ),
                                ),
                                if (game.hasActiveMission) ...[
                                  const SizedBox(height: 10),
                                  GameButton(
                                    label: 'Continue Mission',
                                    icon: Icons.skip_next_rounded,
                                    onPressed: () => _push(context, const MissionMapScreen()),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                GameButton(
                                  label: 'Mission Map',
                                  icon: Icons.map_rounded,
                                  color: GameColors.blue,
                                  onPressed: () => _push(
                                    context,
                                    game.signedIn ? const MissionMapScreen() : const NameScreen(),
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
                                  label: 'NASA Learning',
                                  icon: Icons.satellite_alt_rounded,
                                  color: GameColors.blue,
                                  onPressed: () => _push(context, const LearningScreen()),
                                ),
                                const SizedBox(height: 10),
                                GameButton(
                                  label: 'Settings',
                                  icon: Icons.settings,
                                  color: GameColors.blue,
                                  onPressed: () => _push(context, const SettingsScreen()),
                                ),
                                const SizedBox(height: 10),
                                GameButton(
                                  label: 'Exit Game',
                                  icon: Icons.exit_to_app_rounded,
                                  color: GameColors.red,
                                  onPressed: () => SystemNavigator.pop(),
                                ),
                              ],
                            ),
                          ),
                          if (game.bestScore > 0) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                const Icon(Icons.emoji_events_rounded, color: GameColors.yellow, size: 20),
                                const SizedBox(width: 6),
                                Text('Best score: ${game.bestScore}',
                                    style: const TextStyle(
                                        color: GameColors.yellow, fontSize: 16, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (game.signedIn)
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AstronautAvatar(id: game.astronaut, size: 110, ring: const Color(0xFF45E6FF)),
                          const SizedBox(height: 8),
                          Text(
                            'Astronaut ${AstronautAvatar.displayName(game.astronaut)}',
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
