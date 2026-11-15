import 'package:flutter/material.dart';

import '../models.dart';
import '../services/game_controller.dart';
import '../widgets/ui.dart';
import 'menu_screen.dart';
import 'mission_map_screen.dart';

/// Cinematic ending after Day 7: the colony standing, Earth in the sky,
/// the final score, badges and the way back to the menu.
class FinalEndingScreen extends StatefulWidget {
  const FinalEndingScreen({super.key, required this.won, required this.score});

  final bool won;
  final int score;

  @override
  State<FinalEndingScreen> createState() => _FinalEndingScreenState();
}

class _FinalEndingScreenState extends State<FinalEndingScreen> {
  bool _busy = false;

  Future<void> _playAgain() async {
    final game = GameScope.of(context);
    setState(() => _busy = true);
    try {
      await game.startMission();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const MissionMapScreen()),
        (r) => r.isFirst,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, 'Mission Control', e.message);
    }
  }

  void _finalReport() {
    final mission = GameScope.of(context).mission;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: GlassPanel(
            borderColor: const Color(0xFF45E6FF),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('FINAL MISSION REPORT',
                    style: TextStyle(color: Color(0xFF45E6FF), fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.6)),
                const SizedBox(height: 10),
                if (mission != null)
                  for (final key in resourceKeys)
                    ResourceBar(resource: key, value: mission.levels[key] ?? 0),
                const SizedBox(height: 8),
                Text('Final score: ${widget.score} · Best: ${GameScope.of(context).bestScore}',
                    style: const TextStyle(color: GameColors.yellow, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                GameButton(label: 'Close', onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final won = widget.won;
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(won ? 'assets/images/trophy.jpg' : 'assets/images/moon.jpg', fit: BoxFit.cover),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99070B18), Color(0xEE070B18)],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events_rounded, color: GameColors.yellow, size: 64),
                      Text(
                        won ? 'MISSION COMPLETED!' : 'GAME OVER',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: won ? const Color(0xFF45E6FF) : GameColors.red,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          shadows: const [Shadow(color: Color(0xFF45E6FF), blurRadius: 30)],
                        ),
                      ),
                      if (won)
                        const Text('YOU SURVIVED SEVEN DAYS ON THE MOON!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      const SizedBox(height: 14),
                      GlassPanel(
                        borderColor: won ? GameColors.yellow : GameColors.red,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AstronautAvatar(id: game.astronaut, size: 70, ring: won ? GameColors.yellow : GameColors.red),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Total score: ${widget.score}',
                                    style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                                Text('Days completed: ${won ? 7 : (game.mission?.currentDay ?? 1) - 1} / 7',
                                    style: const TextStyle(color: Color(0xFFB9C6F2), fontSize: 14, fontWeight: FontWeight.w700)),
                                Text('Colony status: ${won ? 'Survived' : 'Lost'}',
                                    style: TextStyle(
                                        color: won ? GameColors.green : GameColors.red,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800)),
                                if (game.bestScore > 0)
                                  Text('Best score: ${game.bestScore}',
                                      style: const TextStyle(color: GameColors.yellow, fontSize: 14, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Achievement badges.
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _badge(Icons.flag_rounded, '7 Days', won),
                          _badge(Icons.home_rounded, 'Colony Builder', won),
                          _badge(Icons.science_rounded, 'Scientist', won),
                          _badge(Icons.star_rounded, 'Best ${game.bestScore}', game.bestScore > 0),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          GameButton(label: 'View Final Report', icon: Icons.article_rounded, color: GameColors.blue,
                              onPressed: _finalReport),
                          GameButton(
                              label: won ? 'Play Again' : 'Try Again',
                              icon: Icons.replay,
                              color: GameColors.yellow,
                              busy: _busy,
                              onPressed: _playAgain),
                          GameButton(
                            label: 'Main Menu',
                            icon: Icons.home,
                            color: GameColors.blue,
                            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute<void>(builder: (_) => const MenuScreen()), (r) => r.isFirst),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String text, bool earned) {
    final c = earned ? GameColors.yellow : const Color(0xFF6B7399);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: c, size: 17),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      ),
    );
  }
}
