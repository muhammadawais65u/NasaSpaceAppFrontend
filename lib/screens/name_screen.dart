import 'package:flutter/material.dart';

import '../models.dart';
import '../services/game_controller.dart';
import '../widgets/ui.dart';
import 'mission_map_screen.dart';
import 'story_screen.dart';

/// The only sign-in step: type a first name. No email, no password.
class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final TextEditingController _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please type your name.');
      return;
    }
    final game = GameScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await game.signInWithName(name);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => game.hasActiveMission ? const MissionMapScreen() : const StoryScreen(),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SpaceBackground(
      maxWidth: 480,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: RoundIconButton(
                icon: Icons.arrow_back, tooltip: 'Back', onPressed: () => Navigator.of(context).pop()),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: GlassPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const TitleBanner('What is your name?'),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _name,
                        autofocus: true,
                        maxLength: 20,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          labelText: 'Your first name',
                          prefixIcon: const Icon(Icons.person),
                          filled: true,
                          fillColor: const Color(0xFF0A1238),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 6),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: GameColors.yellow, fontWeight: FontWeight.w700)),
                      ],
                      const SizedBox(height: 12),
                      GameButton(label: 'Sign In', icon: Icons.login, big: true, busy: _busy, onPressed: _submit),
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
