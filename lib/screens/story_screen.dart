import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/ui.dart';
import 'astronaut_select_screen.dart';
import 'mission_map_screen.dart';
import '../services/game_controller.dart';

/// Cinematic story intro: the year 2045, the storm, seven days ahead.
class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key});

  static const String text =
      'In the year 2045, humanity established its first permanent lunar colony. '
      'During a routine exploration mission, a powerful lunar storm damaged the '
      "colony's systems and isolated an astronaut from Mission Control.\n\n"
      'With limited oxygen, food, water and power, the astronaut must survive '
      'seven dangerous days, restore the colony and complete important '
      'scientific discoveries.\n\n'
      'Every decision matters. Every resource counts. Your adventure begins now!';

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  int _chars = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 18), (_) {
      if (!mounted) return;
      setState(() => _chars = (_chars + 2).clamp(0, StoryScreen.text.length));
      if (_chars >= StoryScreen.text.length) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _done => _chars >= StoryScreen.text.length;

  void _skip() {
    _timer?.cancel();
    setState(() => _chars = StoryScreen.text.length);
  }

  Future<void> _continue() async {
    final game = GameScope.of(context);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => game.hasActiveMission ? const MissionMapScreen() : const AstronautSelectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/moon.jpg', fit: BoxFit.cover),
          Container(color: const Color(0xB3070B18)),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.podcasts_rounded, color: Color(0xFF45E6FF), size: 22),
                          SizedBox(width: 8),
                          Text('MISSION CONTROL · TRANSMISSION',
                              style: TextStyle(
                                  color: Color(0xFF45E6FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.5)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GlassPanel(
                        borderColor: const Color(0xFF45E6FF),
                        child: SizedBox(
                          width: double.infinity,
                          height: 240,
                          child: SingleChildScrollView(
                            child: Text(
                              StoryScreen.text.substring(0, _chars),
                              style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.55),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!_done)
                            TextButton(
                              onPressed: _skip,
                              child: const Text('Skip Story',
                                  style: TextStyle(color: Color(0xFFB9C6F2), fontSize: 15, fontWeight: FontWeight.w700)),
                            )
                          else
                            GameButton(
                              label: 'Continue',
                              icon: Icons.arrow_forward_rounded,
                              color: GameColors.yellow,
                              big: true,
                              onPressed: _continue,
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
}
