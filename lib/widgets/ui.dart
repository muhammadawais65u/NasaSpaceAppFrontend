import 'dart:math' as math;

import 'package:flutter/material.dart';

class GameColors {
  static const Color spaceTop = Color(0xFF070B2B);
  static const Color spaceBottom = Color(0xFF2B1D73);
  static const Color panel = Color(0xE6101C52);
  static const Color panelBorder = Color(0xFF5CC8FF);
  static const Color yellow = Color(0xFFFFC928);
  static const Color green = Color(0xFF34C759);
  static const Color blue = Color(0xFF2D7FF9);
  static const Color red = Color(0xFFE5484D);
  static const Color purple = Color(0xFF8E5BFF);
  static const Color textDim = Color(0xFFB9C6F2);
}

class ResourceMeta {
  const ResourceMeta(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static const Map<String, ResourceMeta> all = {
    'oxygen_level': ResourceMeta('Oxygen', Icons.air, Color(0xFF4DD0E1)),
    'power_level': ResourceMeta('Power', Icons.bolt, Color(0xFFFFD54F)),
    'water_level': ResourceMeta('Water', Icons.water_drop, Color(0xFF42A5F5)),
    'food_level': ResourceMeta('Food', Icons.eco, Color(0xFF66BB6A)),
    'radiation_protection_level': ResourceMeta('Shield', Icons.shield, Color(0xFFBA8CFF)),
  };

  static ResourceMeta of(String key) => all[key] ?? const ResourceMeta('?', Icons.help_outline, Colors.white);
}

/// Night sky with stars and a Moon-surface horizon, drawn in code.
/// Optionally shows a picture behind a dark tint.
class SpaceBackground extends StatelessWidget {
  const SpaceBackground({super.key, required this.child, this.image, this.maxWidth = 1100});

  final Widget child;
  final String? image;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.spaceTop,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _SkyPainter()),
          if (image != null) ...[
            Image.asset(image!, fit: BoxFit.cover),
            Container(color: const Color(0xB3070B2B)),
          ],
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(padding: const EdgeInsets.all(12), child: child),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GameColors.spaceTop, GameColors.spaceBottom],
        ).createShader(rect),
    );

    final rnd = math.Random(7);
    final star = Paint();
    for (var i = 0; i < 160; i++) {
      final p = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height * 0.8);
      star.color = Colors.white.withAlpha(90 + rnd.nextInt(160));
      canvas.drawCircle(p, 0.6 + rnd.nextDouble() * 1.4, star);
    }

    final top = size.height * 0.80;
    final ground = Path()
      ..moveTo(0, top + 18)
      ..quadraticBezierTo(size.width * 0.5, top - 26, size.width, top + 18)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final groundRect = Rect.fromLTRB(0, top - 26, size.width, size.height);
    canvas.drawPath(
      ground,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9AA0BC), Color(0xFF4A4E6E)],
        ).createShader(groundRect),
    );
    final crater = Paint()..color = const Color(0x553A3D5C);
    for (var i = 0; i < 9; i++) {
      final c = Offset(rnd.nextDouble() * size.width, top + 30 + rnd.nextDouble() * (size.height - top - 30));
      final w = 26 + rnd.nextDouble() * 60;
      canvas.drawOval(Rect.fromCenter(center: c, width: w, height: w * 0.32), crater);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.borderColor});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final border = borderColor ?? GameColors.panelBorder;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: GameColors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border, width: 2),
        boxShadow: [BoxShadow(color: border.withAlpha(70), blurRadius: 18, spreadRadius: 1)],
      ),
      child: child,
    );
  }
}

class TitleBanner extends StatelessWidget {
  const TitleBanner(this.text, {super.key, this.color = GameColors.blue});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.25)!, color],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white70, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
        ),
      ),
    );
  }
}

class GameButton extends StatelessWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = GameColors.green,
    this.big = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final bool big;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final textColor = color == GameColors.yellow ? const Color(0xFF3A2500) : Colors.white;
    final radius = BorderRadius.circular(big ? 20 : 16);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? onPressed : null,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(color, Colors.white, 0.3)!, color],
              ),
              borderRadius: radius,
              border: Border.all(color: Colors.white70, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 4))],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: big ? 30 : 20, vertical: big ? 16 : 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: textColor),
                    )
                  else if (icon != null)
                    Icon(icon, color: textColor, size: big ? 28 : 22),
                  if (busy || icon != null) const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: big ? 22 : 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: GameColors.blue,
        shape: const CircleBorder(side: BorderSide(color: Colors.white70, width: 2)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, color: Colors.white, size: 24, semanticLabel: tooltip),
          ),
        ),
      ),
    );
  }
}

class AstronautAvatar extends StatelessWidget {
  const AstronautAvatar({super.key, required this.id, this.size = 64, this.ring = GameColors.yellow});

  final String id;
  final double size;
  final Color ring;

  static String asset(String id) => 'assets/images/astronaut_$id.jpg';

  static String displayName(String id) {
    return id.isEmpty ? id : id[0].toUpperCase() + id.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
      ),
      child: ClipOval(
        child: Image.asset(
          asset(id),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          semanticLabel: 'Astronaut ${displayName(id)}',
        ),
      ),
    );
  }
}

/// Small pill for the top of the mission hub: icon, name and percent.
class ResourceChip extends StatelessWidget {
  const ResourceChip({super.key, required this.resource, required this.value});

  final String resource;
  final int value;

  @override
  Widget build(BuildContext context) {
    final meta = ResourceMeta.of(resource);
    final low = value < 30;
    final color = low ? GameColors.red : meta.color;
    return Semantics(
      label: '${meta.label} $value percent${low ? ', low' : ''}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xCC0A1238),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(low ? Icons.warning_amber_rounded : meta.icon, color: color, size: 22),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(meta.label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  Text('$value%', style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated bar with the change from the last decision, for the result screen.
class ResourceBar extends StatelessWidget {
  const ResourceBar({super.key, required this.resource, required this.value, this.change});

  final String resource;
  final int value;
  final int? change;

  @override
  Widget build(BuildContext context) {
    final meta = ResourceMeta.of(resource);
    final low = value < 30;
    final delta = change ?? 0;
    final from = ((value - delta).clamp(0, 100)) / 100.0;
    return Semantics(
      label: '${meta.label} $value percent'
          '${delta == 0 ? '' : ', changed by $delta'}${low ? ', low' : ''}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Icon(meta.icon, color: meta.color, size: 24),
              const SizedBox(width: 8),
              SizedBox(
                width: 62,
                child: Text(meta.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: from, end: value / 100.0),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 16,
                      backgroundColor: const Color(0xFF1B2A6B),
                      valueColor: AlwaysStoppedAnimation<Color>(low ? GameColors.red : meta.color),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: Text('$value%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  delta == 0 ? '' : (delta > 0 ? '+$delta' : '$delta'),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: delta > 0 ? GameColors.green : GameColors.red,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows what an option gives and what it costs, so no choice looks free.
class EffectChips extends StatelessWidget {
  const EffectChips({super.key, required this.effects});

  final Map<String, int> effects;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    for (final key in ResourceMeta.all.keys) {
      final v = effects[key] ?? 0;
      if (v == 0) continue;
      final meta = ResourceMeta.of(key);
      chips.add(_chip(meta.icon, v > 0 ? '+$v' : '$v', v > 0 ? GameColors.green : GameColors.red,
          '${meta.label} ${v > 0 ? 'plus' : 'minus'} ${v.abs()}'));
    }
    final score = effects['score'] ?? 0;
    if (score != 0) {
      chips.add(_chip(Icons.star_rounded, score > 0 ? '+$score' : '$score', GameColors.yellow, 'Points $score'));
    }
    return Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: chips);
  }

  Widget _chip(IconData icon, String text, Color color, String label) {
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(40),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Honest label for where NASA data came from.
class DataBadge extends StatelessWidget {
  const DataBadge({super.key, required this.status, required this.source, this.retrievedAt});

  final String status;
  final String source;
  final DateTime? retrievedAt;

  @override
  Widget build(BuildContext context) {
    String text;
    Color color;
    switch (status) {
      case 'live':
        text = 'Live from $source';
        color = GameColors.green;
        break;
      case 'cached':
        text = 'Saved $source data';
        color = GameColors.yellow;
        break;
      case 'archived':
        text = 'Past $source data';
        color = GameColors.yellow;
        break;
      default:
        text = '$source data is not available right now';
        color = GameColors.textDim;
    }
    final at = retrievedAt;
    if (at != null && status != 'unavailable') text = '$text - ${formatDate(at)}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))),
      ],
    );
  }
}

String formatDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final u = d.toUtc();
  return '${u.day} ${months[u.month - 1]} ${u.year}';
}

/// Tilts its child in 3D towards the pointer, with a gentle floating motion.
class Tilt3D extends StatefulWidget {
  const Tilt3D({super.key, required this.child, this.maxTilt = 0.22, this.float = true});

  final Widget child;
  final double maxTilt;
  final bool float;

  @override
  State<Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<Tilt3D> with SingleTickerProviderStateMixin {
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(seconds: 4));
  Offset _pointer = Offset.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFloat();
  }

  @override
  void didUpdateWidget(covariant Tilt3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFloat();
  }

  void _syncFloat() {
    final still = MediaQuery.of(context).disableAnimations || !widget.float;
    if (still) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  void _track(PointerEvent e, Size size) {
    if (size.isEmpty) return;
    setState(() {
      _pointer = Offset(
        (e.localPosition.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
        (e.localPosition.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onExit: (_) => setState(() => _pointer = Offset.zero),
      child: Listener(
        onPointerHover: (e) => _track(e, context.size ?? Size.zero),
        onPointerMove: (e) => _track(e, context.size ?? Size.zero),
        onPointerUp: (_) => setState(() => _pointer = Offset.zero),
        child: AnimatedBuilder(
          animation: _float,
          child: widget.child,
          builder: (context, child) {
            final moving = _float.isAnimating;
            final wave = moving ? Curves.easeInOut.transform(_float.value) * 2 - 1 : 0.0;
            final matrix = Matrix4.identity()
              ..setEntry(3, 2, 0.0014)
              ..rotateX(-_pointer.dy * widget.maxTilt)
              ..rotateY(_pointer.dx * widget.maxTilt + wave * 0.05);
            return Transform.translate(
              offset: Offset(0, wave * 6),
              child: Transform(alignment: Alignment.center, transform: matrix, child: child),
            );
          },
        ),
      ),
    );
  }
}

Future<void> showMessage(BuildContext context, String title, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF14226A),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      content: Text(message, style: const TextStyle(color: Colors.white, fontSize: 16)),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
      ],
    ),
  );
}
