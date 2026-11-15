import 'package:flutter/material.dart';

import '../services/game_controller.dart';
import '../widgets/ui.dart';
import 'menu_screen.dart';

/// Cinematic splash: title over the hero image, a loading bar, then the
/// main menu once Mission Control (the backend) is ready.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
        ..addListener(_maybeGo)
        ..forward();
  bool _navigated = false;

  // The animation finishing does not rebuild this widget, so check on every
  // tick too — otherwise a backend that answers mid-animation strands us here.
  void _maybeGo() {
    if (_anim.value <= 0.75 || !mounted) return;
    if (GameScope.of(context).phase == AppPhase.ready) _go();
  }

  void _go() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const MenuScreen()));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    // Move on when the backend is ready AND the animation has finished.
    if (game.phase == AppPhase.ready && _anim.value > 0.75) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _go());
    }
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/hero.jpg', fit: BoxFit.cover),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99070B18), Color(0x33070B18), Color(0xF2070B18)],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                FadeTransition(
                  opacity: _anim,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.3), end: Offset.zero)
                        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic)),
                    child: Column(
                      children: [
                        Text('JUNIOR ASTRONAUT',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFF45E6FF).withAlpha(255),
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 6,
                              shadows: const [Shadow(color: Color(0xFF45E6FF), blurRadius: 24)],
                            )),
                        const SizedBox(height: 6),
                        const Text('MOON SURVIVAL ADVENTURE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              shadows: [Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 4))],
                            )),
                        const SizedBox(height: 10),
                        Text(
                          'Your Mission. Your Decisions. Your Survival.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: const Color(0xFFB9C6F2), fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                if (game.phase == AppPhase.error) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(game.errorMessage ?? 'Cannot reach Mission Control.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: GameColors.yellow, fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 10),
                  GameButton(label: 'Try Again', icon: Icons.refresh, onPressed: game.start),
                ] else ...[
                  SizedBox(
                    width: 220,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: game.phase == AppPhase.ready ? _anim.value : null,
                        minHeight: 8,
                        backgroundColor: Colors.white.withAlpha(40),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF45E6FF)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    game.phase == AppPhase.ready ? 'Loading your adventure...' : 'Contacting Mission Control...',
                    style: const TextStyle(color: Color(0xFFB9C6F2), fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
