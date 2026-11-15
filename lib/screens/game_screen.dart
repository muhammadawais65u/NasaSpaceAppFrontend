import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/lunar_scene.dart';
import '../game/mission_days.dart';
import '../models.dart';
import '../services/game_controller.dart';
import '../widgets/ui.dart';
import 'mission_screen.dart';

enum _Phase { explore, building, busy }

/// The playable mission. The objectives of today's mission come one at a
/// time: a glowing pad shows where to build the next one, every build uses
/// colony resources, and every finished building stays on the Moon. After
/// the last objective the player builds the colony core, which reports the
/// day to Mission Control.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.info});

  final MissionInfo info;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  static const Offset _start = Offset(4, 6);
  static const double _padRadius = 3.2;
  static const double _buildSeconds = 3.0;
  static const List<Color> _padColors = [
    Color(0xFF34C759),
    Color(0xFF2D7FF9),
    Color(0xFFFFC928),
    Color(0xFF8E5BFF),
  ];

  late final AnimationController _anim;
  late final LunarScenery _scenery;
  late final List<BuildPad> _pads;

  final FocusNode _focus = FocusNode();
  final Set<LogicalKeyboardKey> _keys = {};
  final math.Random _rnd = math.Random();
  Offset _joy = Offset.zero;
  bool _jumpHeld = false;

  _Phase _phase = _Phase.explore;

  // Astronaut.
  Offset _pos = _start;
  double _heading = 0;
  double _camYaw = 0;
  bool _moving = false;
  double _alt = 0;
  double _vy = 0;
  final List<DustParticle> _particles = [];

  // Building.
  int _step = 0; // objectives finished so far
  int _near = -1; // pad you are standing on (-1 = none)
  bool _final = false; // building the colony core
  int _choice = 0; // option reported for the final building
  double _buildT = 0;
  final Map<String, int> _spent = {}; // resources used by finished builds

  List<String> get _objectives => widget.info.objectives;
  DayTheme get _theme => themeForDay(widget.info.day);
  InteractKind get _currentKind =>
      _final || _step >= _objectives.length ? InteractKind.build : _theme.kindOf(_step);

  String _toast = '';
  double _toastLeft = 0;
  double _clock = 0;
  double _lastTime = 0;

  @override
  void initState() {
    super.initState();
    _scenery = LunarScenery(widget.info.day * 97 + 13);
    // One pad per objective, fanned out in front of the lander, plus the
    // colony core where the final decision is built.
    final n = _objectives.length;
    _pads = [
      for (var i = 0; i < n; i++)
        BuildPad(
          Offset(
            math.sin((i - (n - 1) / 2) * 0.8) * 22,
            math.cos((i - (n - 1) / 2) * 0.8) * 22,
          ),
          _objectives[i],
          _padColors[i % _padColors.length],
          kind: _theme.kindOf(i),
        ),
      const BuildPad(Offset(0, -24), 'Colony core', Color(0xFFFFB347)),
    ];
    _say('Walk to the glowing pad and press E to build it. Every build uses resources.', 7);
    // If NASA DONKI fed this mission a real space-weather event, Mission
    // Control opens the day by telling the astronaut about it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final game = GameScope.of(context);
      final e = game.scenarioEvent;
      if (e == null) return;
      final when = e.date == null ? '' : ' on ${formatDate(e.date!)}';
      final storm = game.mission?.alertLevel == 'storm';
      _say(
        'NASA really saw this: ${e.title}$when.'
        "${storm ? ' Solar storm - your shield drains faster!' : ''} "
        'Now walk to the glowing pad and press E.',
        8,
      );
    });
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_tick)
      ..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _say(String text, [double seconds = 3.5]) {
    _toast = text;
    _toastLeft = seconds;
  }

  // ----------------------------------------------------------------- loop

  void _tick() {
    final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
    if (_lastTime == 0) _lastTime = t;
    final dt = math.min(0.05, math.max(0.0, t - _lastTime));
    _lastTime = t;
    _clock += dt;
    if (_toastLeft > 0) _toastLeft -= dt;

    if (_phase == _Phase.explore) {
      _move(dt);
      _jumpPhysics(dt);
      _near = _nearestPad();
    } else {
      _moving = false;
    }
    if (_phase == _Phase.building) {
      _buildT = math.min(1.0, _buildT + dt / _buildSeconds);
      if (_buildT >= 1) {
        if (_final) {
          _submit(widget.info.options[_choice]);
        } else {
          _finishStep();
        }
      }
    }
    _updateParticles(dt);

    // Camera yaw eases toward the astronaut's heading so turning is smooth.
    var diff = _heading - _camYaw;
    while (diff > math.pi) {
      diff -= 2 * math.pi;
    }
    while (diff < -math.pi) {
      diff += 2 * math.pi;
    }
    _camYaw += diff * math.min(1.0, dt * 4);
    if (mounted) setState(() {});
  }

  /// The pad of the current objective - or the colony core once every
  /// objective is built.
  int _nearestPad() {
    final idx = _step < _objectives.length ? _step : _pads.length - 1;
    return (_pads[idx].pos - _pos).distance < _padRadius ? idx : -1;
  }

  /// turn: -1 left … +1 right; fwd: -1 back … +1 forward.
  (double, double) _controls() {
    var turn = _joy.dx;
    var fwd = -_joy.dy;
    bool has(LogicalKeyboardKey k) => _keys.contains(k);
    turn += (has(LogicalKeyboardKey.keyD) || has(LogicalKeyboardKey.arrowRight) ? 1 : 0) -
        (has(LogicalKeyboardKey.keyA) || has(LogicalKeyboardKey.arrowLeft) ? 1 : 0);
    fwd += (has(LogicalKeyboardKey.keyW) || has(LogicalKeyboardKey.arrowUp) ? 1 : 0) -
        (has(LogicalKeyboardKey.keyS) || has(LogicalKeyboardKey.arrowDown) ? 1 : 0) * 0.6;
    return (turn.clamp(-1.0, 1.0), fwd.clamp(-1.0, 1.0));
  }

  void _move(double dt) {
    final (turn, fwd) = _controls();
    _heading += turn * 2.0 * dt;
    _moving = fwd.abs() > 0.05;
    if (!_moving) return;
    final dir = Offset(math.sin(_heading), math.cos(_heading));
    var p = _pos + dir * (6.0 * fwd * dt);
    final r = p.distance;
    if (r > LunarScenePainter.worldRadius) p = p * (LunarScenePainter.worldRadius / r);
    _pos = p;
    // Kick up dust while walking.
    if (_alt <= 0 && _particles.length < 120 && _rnd.nextDouble() < 0.5) {
      _particles.add(DustParticle(
        _pos.dx + (_rnd.nextDouble() - 0.5) * 0.5,
        _pos.dy + (_rnd.nextDouble() - 0.5) * 0.5,
        -dir.dx * fwd * 1.5 + (_rnd.nextDouble() - 0.5),
        -dir.dy * fwd * 1.5 + (_rnd.nextDouble() - 0.5),
        DustParticle.maxLife,
      ));
    }
  }

  /// Moon gravity: a small hop.
  void _jumpPhysics(double dt) {
    final wantJump = _jumpHeld || _keys.contains(LogicalKeyboardKey.space);
    if (wantJump && _alt <= 0) _vy = 4.2;
    _vy -= 5 * dt;
    _alt += _vy * dt;
    if (_alt <= 0) {
      _alt = 0;
      _vy = 0;
    }
  }

  void _updateParticles(double dt) {
    for (var i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.life -= dt;
      p.x += p.vx * dt;
      p.z += p.vz * dt;
      if (p.life <= 0) _particles.removeAt(i);
    }
  }

  // ------------------------------------------------------------- building

  void _build() {
    if (_phase != _Phase.explore || _near < 0) return;
    final isFinal = _near >= _objectives.length;
    setState(() {
      _final = isFinal;
      _choice = 0;
      _buildT = 0;
      _phase = _Phase.building;
      _near = -1;
      _jumpHeld = false;
      _say(
        isFinal
            ? 'Building: Colony core - ${widget.info.options.first.label}'
            : '${_currentKind.verb}: ${_objectives[_step]}',
        4,
      );
    });
  }

  void _finishStep() {
    final built = _objectives[_step];
    final kind = _theme.kindOf(_step);
    final kindCost = kind.cost;
    _step++;
    _buildT = 0;
    _near = -1;
    for (final e in kindCost.entries) {
      _spent[e.key] = (_spent[e.key] ?? 0) + e.value;
    }
    _phase = _Phase.explore;
    if (_step >= _objectives.length) {
      _say('All objectives built! Walk to the gold Colony core pad and press E.', 6);
    } else {
      _say('Built: $built. Next objective is lit up.', 4);
    }
    // Each finished job teaches the astronaut something about the work.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showLesson(kind, built, kindCost);
    });
  }

  /// Pop-up after each objective: why astronauts do this job and how it
  /// helps the crew - plus the resources it just used.
  void _showLesson(InteractKind kind, String built, Map<String, int> cost) {
    final accent = _theme.accent;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: GlassPanel(
            borderColor: accent,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: accent.withAlpha(50),
                  child: Icon(kind.icon, color: accent, size: 30),
                ),
                const SizedBox(height: 8),
                Text('${kind.verb} done!',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                Text(built,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text('WHY DO ASTRONAUTS ${kind.verb.toUpperCase()}?',
                    style: const TextStyle(
                        color: GameColors.textDim, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(kind.lesson,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [for (final e in cost.entries) _costChip(e.key, -e.value)],
                ),
                const SizedBox(height: 12),
                GameButton(label: 'Got it!', icon: Icons.check_rounded, onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The building is finished: tell Mission Control, then show what it cost.
  Future<void> _submit(DecisionOption option) async {
    if (_phase != _Phase.building) return;
    final game = GameScope.of(context);
    setState(() => _phase = _Phase.busy);
    try {
      final result = await game.decide(widget.info, option);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => OutcomeScreen(info: widget.info, option: option, result: result),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.explore;
        _final = false;
        _buildT = 0;
      });
      await showMessage(context, 'Mission Control', e.message);
      if (!mounted) return;
      if (e.code == 'version_conflict' || e.code == 'mission_not_active') {
        Navigator.of(context).pop();
      }
    }
  }

  // ------------------------------------------------------------ keyboard

  bool _handleKey(KeyEvent event) {
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.keyE) {
      if (event is KeyDownEvent) _build();
      return true;
    }
    final isMove = k == LogicalKeyboardKey.keyW ||
        k == LogicalKeyboardKey.keyA ||
        k == LogicalKeyboardKey.keyS ||
        k == LogicalKeyboardKey.keyD ||
        k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.space;
    if (!isMove) return false;
    if (event is KeyDownEvent) {
      _keys.add(k);
    } else if (event is KeyUpEvent) {
      _keys.remove(k);
    }
    return true;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    return _handleKey(event) ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final mission = game.mission;
    // The mission moved on (or ended) while we were playing: go back to the hub.
    if (mission == null || !mission.isActive || mission.currentDay != widget.info.day) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    final exploring = _phase == _Phase.explore;
    final showToast = _toast.isNotEmpty && _toastLeft > 0 && (exploring || _phase == _Phase.building) && _near < 0;
    final levels = mission.levels;
    // Resources already used by finished builds are subtracted everywhere.
    final spent = {for (final k in resourceKeys) k: _spent[k] ?? 0};
    final lowResources = [
      for (final k in resourceKeys)
        if (((levels[k] ?? 0) - spent[k]!).clamp(0, 100) < 30) ResourceMeta.of(k).label,
    ];

    final n = _objectives.length;
    final chosen = _final ? widget.info.options[_choice] : null;

    // Arrow / light pillar toward the current pad (or the colony core).
    final Offset? guide = (exploring && _near < 0) ? _pads[_step < n ? _step : n].pos : null;
    final showCard = (exploring && _near >= 0) || _phase == _Phase.building || (_phase == _Phase.busy);

    return Scaffold(
      backgroundColor: const Color(0xFF02030A),
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _focus.requestFocus(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: LunarScenePainter(
                  scenery: _scenery,
                  astronaut: _pos,
                  altitude: _alt,
                  heading: _heading,
                  camYaw: _camYaw,
                  moving: _moving,
                  time: _clock,
                  particles: _particles,
                  target: guide,
                  pads: _pads,
                  heritage: _heritagePads(game),
                  activePad: _near,
                  buildingPad: (_phase == _Phase.building || _phase == _Phase.busy) ? (_final ? n : _step) : -1,
                  buildProgress: _buildT,
                  visibleCount: _step >= n ? n + 1 : _step + 1,
                  builtCount: _step,
                  day: widget.info.day,
                  suitAccent: suitAccentFor(game.astronaut),
                ),
              ),
              SafeArea(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _buildHud(levels, chosen),
                        const Spacer(),
                        _buildBottom(exploring),
                      ],
                    ),
                    if (showToast) Positioned(top: 8, left: 0, right: 0, child: Center(child: _buildToast())),
                    Positioned(
                      bottom: 138,
                      left: 0,
                      right: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (lowResources.isNotEmpty && exploring && _near < 0) _buildLowWarning(lowResources),
                          if (showCard) _buildPadCard(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panelBox({required Widget child, double? width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xCC0A1238),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GameColors.panelBorder, width: 2),
      ),
      child: child,
    );
  }

  /// Mission on the left, colony resources on the right.
  Widget _buildHud(Map<String, int> levels, DecisionOption? preview) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RoundIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Back to missions',
                onPressed: _phase == _Phase.explore ? () => Navigator.of(context).pop() : () {},
              ),
              const SizedBox(height: 8),
              _missionPanel(),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _resourcePanel(levels, preview),
              const SizedBox(height: 8),
              _MiniMap(pos: _pos, pads: _pads, step: _step, objectives: _objectives.length),
            ],
          ),
        ],
      ),
    );
  }

  Widget _missionPanel() {
    final info = widget.info;
    final n = _objectives.length;
    final finalStage = _step >= n;
    return _panelBox(
      width: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('DAY ${info.day} · ${info.title.toUpperCase()}',
              style: const TextStyle(color: Color(0xFFFFB347), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(_theme.tagline.toUpperCase(),
              style: const TextStyle(color: GameColors.yellow, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(info.scenario, style: const TextStyle(color: GameColors.textDim, fontSize: 11.5, height: 1.3)),
          const SizedBox(height: 8),
          Text(finalStage ? 'COLONY CORE' : 'OBJECTIVE ${_step + 1} OF $n',
              style: const TextStyle(color: GameColors.yellow, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(_currentKind.icon, color: GameColors.yellow, size: 18),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  finalStage ? 'Build the colony core to report to Mission Control.' : _objectives[_step],
                  style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800, height: 1.25),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i <= n; i++)
                Container(
                  width: 14,
                  height: 6,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: i < _step ? GameColors.green : Colors.white.withAlpha(i == _step ? 140 : 50),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resourcePanel(Map<String, int> levels, DecisionOption? option) {
    // While building, the bars slide toward the cost of the build: the
    // colony core uses the reported option's effects, an objective uses the
    // cost of its interaction kind (scan costs power, repairs cost tools...).
    final k = _buildT.clamp(0.0, 1.0);
    final buildingStep = _phase == _Phase.building && !_final;
    final stepCost = buildingStep ? _theme.kindOf(_step).cost : const <String, int>{};
    return _panelBox(
      width: 230,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('COLONY RESOURCES',
              style: TextStyle(color: GameColors.textDim, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          for (final key in resourceKeys)
            _resRow(
              ResourceMeta.of(key).label.toUpperCase(),
              ((levels[key] ?? 0) - (_spent[key] ?? 0)) +
                  (option?.effects[key] ?? 0) * k -
                  (stepCost[key] ?? 0) * (buildingStep ? k : 0),
              ResourceMeta.of(key).color,
              option?.effects[key] ?? -(stepCost[key] ?? 0),
            ),
        ],
      ),
    );
  }

  Widget _resRow(String label, double value, Color color, int delta) {
    final v = value.clamp(0.0, 100.0);
    final c = v < 30 ? const Color(0xFFFF7A7A) : color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: GameColors.textDim, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: v / 100,
                minHeight: 8,
                backgroundColor: Colors.white.withAlpha(30),
                valueColor: AlwaysStoppedAnimation(c),
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text('${v.round()}%',
                textAlign: TextAlign.right,
                style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.w800)),
          ),
          SizedBox(
            width: 30,
            child: Text(
              delta == 0 ? '' : (delta > 0 ? '+$delta' : '$delta'),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: delta > 0 ? GameColors.green : const Color(0xFFFF7A7A),
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToast() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: _panelBox(
        child: Text(_toast,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, height: 1.3)),
      ),
    );
  }

  Widget _buildLowWarning(List<String> low) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: GameColors.red.withAlpha(60),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GameColors.red, width: 1.5),
        ),
        child: Text('${low.join(', ')} is low! Choose carefully.',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
      ),
    );
  }

  /// Shown on the current pad: what is being built, and the Build button.
  Widget _buildPadCard() {
    final building = _phase != _Phase.explore;
    final n = _objectives.length;
    final color = _pads[_final ? n : math.min(_step, n)].color;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: GlassPanel(
        borderColor: color,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _final || _step >= n ? 'Colony core' : _objectives[_step],
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (building) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _buildT,
                  minHeight: 10,
                  backgroundColor: Colors.white.withAlpha(30),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _phase == _Phase.busy ? 'Reporting to Mission Control...' : _currentKind.doing,
                style: const TextStyle(color: GameColors.textDim, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ] else ...[
              _costPreview(),
              const SizedBox(height: 8),
              GameButton(label: '${_currentKind.verb} (E)', icon: _currentKind.icon, onPressed: _build),
            ],
          ],
        ),
      ),
    );
  }

  /// Before the player commits, show exactly which resources the action will
  /// use and why - scan costs power, repairs cost tools, and so on.
  Widget _costPreview() {
    if (_final || _step >= _objectives.length) {
      final fx = widget.info.options.first.effects;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('MISSION CONTROL REPORT USES:',
              style: TextStyle(
                  color: GameColors.textDim, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
          const SizedBox(height: 5),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [for (final e in fx.entries) _costChip(e.key, e.value)],
          ),
        ],
      );
    }
    final kind = _theme.kindOf(_step);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${kind.verb.toUpperCase()} USES:',
            style: const TextStyle(
                color: GameColors.textDim, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
        const SizedBox(height: 5),
        Wrap(
          spacing: 5,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [for (final e in kind.cost.entries) _costChip(e.key, -e.value)],
        ),
        const SizedBox(height: 5),
        Text(kind.costReason,
            textAlign: TextAlign.center,
            style: const TextStyle(color: GameColors.textDim, fontSize: 11, fontWeight: FontWeight.w600, height: 1.25)),
      ],
    );
  }

  Widget _costChip(String key, int value) {
    final meta = ResourceMeta.of(key);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: meta.color.withAlpha(45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: meta.color.withAlpha(170)),
      ),
      child: Text('${meta.label} ${value > 0 ? '+' : ''}$value',
          style: TextStyle(color: meta.color, fontSize: 10.5, fontWeight: FontWeight.w900)),
    );
  }

  /// Everything built on earlier days stays standing: old objectives become
  /// finished structures spread around today's build site.
  List<BuildPad> _heritagePads(GameController game) {
    final list = <BuildPad>[];
    for (var d = 1; d < widget.info.day; d++) {
      final info = game.missionInfo(d);
      if (info == null) continue;
      final theme = themeForDay(d);
      for (var i = 0; i < info.objectives.length; i++) {
        final a = (d * 3.0 + i) * 2.3999632; // golden-angle spread
        final r = 30.0 + ((d * 2 + i) % 3) * 4.0;
        list.add(BuildPad(Offset(math.sin(a) * r, math.cos(a) * r), info.objectives[i], theme.accent,
            kind: theme.kindOf(i)));
      }
    }
    return list;
  }

  Widget _buildBottom(bool exploring) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (exploring) _Joystick(onChanged: (v) => _joy = v) else const SizedBox(width: 120, height: 120),
          const SizedBox(width: 12),
          Expanded(
            child: Center(
              child: Text(
                exploring ? 'A/D turn · W walk · Space jump · E build' : '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (exploring) ...[
            _roundButton(label: _currentKind.verb.toUpperCase(), size: 64, icon: _currentKind.icon, held: false, onDown: _build),
            const SizedBox(width: 10),
            _roundButton(
              label: 'JUMP',
              size: 90,
              icon: Icons.rocket_launch,
              held: _jumpHeld,
              onDown: () => setState(() => _jumpHeld = true),
              onUp: () => setState(() => _jumpHeld = false),
            ),
          ] else
            const SizedBox(width: 90),
        ],
      ),
    );
  }

  Widget _roundButton({
    required String label,
    required double size,
    required IconData? icon,
    required bool held,
    required VoidCallback onDown,
    VoidCallback? onUp,
  }) {
    return Listener(
      onPointerDown: (_) => onDown(),
      onPointerUp: (_) => onUp?.call(),
      onPointerCancel: (_) => onUp?.call(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: GameColors.yellow.withAlpha(held ? 200 : 80),
          border: Border.all(color: GameColors.yellow, width: 3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) Icon(icon, color: Colors.white, size: 28),
            Text(label,
                style: TextStyle(color: Colors.white, fontSize: icon == null ? 22 : 12, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

/// Small circular minimap: lander, objective pads and the astronaut.
class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.pos, required this.pads, required this.step, required this.objectives});

  final Offset pos;
  final List<BuildPad> pads;
  final int step;
  final int objectives;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xCC0A1238),
        border: Border.all(color: GameColors.panelBorder, width: 2),
      ),
      child: CustomPaint(painter: _MiniMapPainter(pos: pos, pads: pads, step: step, objectives: objectives)),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  const _MiniMapPainter({required this.pos, required this.pads, required this.step, required this.objectives});

  final Offset pos;
  final List<BuildPad> pads;
  final int step;
  final int objectives;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final scale = (size.width / 2 - 6) / LunarScenePainter.worldRadius;
    Offset w(Offset p) => c + Offset(p.dx, -p.dy) * scale;

    // Outer rim and faint grid.
    canvas.drawCircle(c, size.width / 2 - 4, Paint()..color = const Color(0x55161F4E));
    canvas.drawCircle(
      c,
      size.width / 2 - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x555CC8FF),
    );

    // Lander at the centre.
    canvas.drawCircle(w(LunarScenePainter.lander), 3, Paint()..color = Colors.white);
    // Landmarks.
    canvas.drawCircle(w(LunarScenePainter.baseDome), 2.5, Paint()..color = const Color(0xFFB9C6F2));
    canvas.drawCircle(w(LunarScenePainter.antenna), 2.5, Paint()..color = const Color(0xFFFFB347));

    for (var i = 0; i < pads.length; i++) {
      final isCore = i == pads.length - 1;
      final current = isCore ? step >= objectives : i == step;
      final done = !isCore && i < step;
      canvas.drawCircle(
        w(pads[i].pos),
        current ? 4 : 2.6,
        Paint()
          ..color = done
              ? const Color(0xFF7BE0A0)
              : isCore
                  ? const Color(0xFFFFB347)
                  : pads[i].color.withAlpha(current ? 255 : 110),
      );
      if (current) {
        canvas.drawCircle(
          w(pads[i].pos),
          7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = pads[i].color,
        );
      }
    }

    // Astronaut, cyan.
    canvas.drawCircle(w(pos), 3, Paint()..color = const Color(0xFF45E6FF));
    canvas.drawCircle(
      w(pos),
      5.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF45E6FF),
    );
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) => true;
}

/// Virtual joystick for touch screens (bottom-left).
class _Joystick extends StatefulWidget {
  const _Joystick({required this.onChanged});

  final ValueChanged<Offset> onChanged;

  @override
  State<_Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<_Joystick> {
  Offset _knob = Offset.zero;
  int? _pointer;

  void _update(Offset local, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    var d = local - center;
    final max = size.width / 2 - 18;
    if (d.distance > max) d *= max / d.distance;
    setState(() => _knob = d);
    widget.onChanged(Offset(d.dx / max, d.dy / max));
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        _pointer = e.pointer;
        _update(e.localPosition, context.size ?? const Size(120, 120));
      },
      onPointerMove: (e) {
        if (e.pointer == _pointer) _update(e.localPosition, context.size ?? const Size(120, 120));
      },
      onPointerUp: (_) => _reset(),
      onPointerCancel: (_) => _reset(),
      child: SizedBox(
        width: 120,
        height: 120,
        child: CustomPaint(painter: _JoystickPainter(_knob)),
      ),
    );
  }

  void _reset() {
    _pointer = null;
    setState(() => _knob = Offset.zero);
    widget.onChanged(Offset.zero);
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter(this.knob);

  final Offset knob;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      size.width / 2 - 6,
      Paint()
        ..color = const Color(0x552B3050)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(center, 34, Paint()..color = const Color(0x88FFFFFF));
    canvas.drawCircle(center + knob, 22, Paint()..color = GameColors.yellow.withAlpha(220));
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) => oldDelegate.knob != knob;
}
