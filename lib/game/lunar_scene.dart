import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/ui.dart';
import 'mission_days.dart';

/// One speck of suit dust kicked up while walking.
class DustParticle {
  DustParticle(this.x, this.z, this.vx, this.vz, this.life);

  double x;
  double z;
  double vx;
  double vz;
  double life;
  static const double maxLife = 0.7;
}

/// A glowing pad on the Moon where one objective is completed. The [kind]
/// decides its floating icon and the structure that grows out of it.
class BuildPad {
  const BuildPad(this.pos, this.label, this.color,
      {this.kind = InteractKind.build});

  final Offset pos;
  final String label;
  final Color color;
  final InteractKind kind;
}

/// A point on the ground plane (x, z) with a size.
class _Spot {
  _Spot(this.pos, this.size);
  final Offset pos;
  final double size;
}

/// Fixed moon-surface details plus sky stars, generated once per mission.
class LunarScenery {
  LunarScenery(int seed) {
    final rnd = math.Random(seed);
    for (var i = 0; i < 90; i++) {
      craters.add(_Spot(_randPoint(rnd, 220), 1.5 + rnd.nextDouble() * 6.5));
    }
    for (var i = 0; i < 80; i++) {
      rocks.add(_Spot(_randPoint(rnd, 180), 0.3 + rnd.nextDouble() * 1.1));
    }
    for (var i = 0; i < 200; i++) {
      pebbles.add(_randPoint(rnd, 150));
    }
    // Fine dust specks that give the plain its gritty moon texture.
    for (var i = 0; i < 700; i++) {
      specks.add((
        _randPoint(rnd, 130),
        rnd.nextDouble() < 0.5 ? 1 : -1,
        0.03 + rnd.nextDouble() * 0.09,
      ));
    }
    for (var i = 0; i < 90; i++) {
      blobs.add(_Spot(_randPoint(rnd, 200), 4 + rnd.nextDouble() * 12));
    }
    // Stars on the upper dome, stored as direction vectors.
    for (var i = 0; i < 220; i++) {
      final a = rnd.nextDouble() * 2 * math.pi;
      final y = 0.12 + rnd.nextDouble() * 0.85;
      final r = math.sqrt(math.max(0, 1 - y * y));
      stars.add(
          (math.cos(a) * r, y, math.sin(a) * r, 0.4 + rnd.nextDouble() * 0.6));
    }
  }

  static Offset _randPoint(math.Random rnd, double radius) {
    final a = rnd.nextDouble() * 2 * math.pi;
    final r = math.sqrt(rnd.nextDouble()) * radius;
    return Offset(math.cos(a) * r, math.sin(a) * r);
  }

  /// Ground height like the trainer: rolling hills (flattened near the
  /// lander) with bowl-shaped depressions under every crater.
  double terrainAt(double x, double z) {
    var y = math.sin(x * .05) * math.cos(z * .06) * 2 +
        math.sin(x * .13 + z * .1) * .5;
    final r = math.sqrt(x * x + z * z);
    final m = ((r - 8) / 14).clamp(0.0, 1.0);
    y *= m * m * (3 - 2 * m);
    for (final c in craters) {
      final dx = x - c.pos.dx, dz = z - c.pos.dy;
      final d2 = dx * dx + dz * dz;
      final rr = c.size * c.size;
      if (d2 < rr * 4) y -= c.size * 0.22 * math.exp(-d2 / rr);
    }
    return y;
  }

  final List<_Spot> craters = [];
  final List<_Spot> rocks = [];
  final List<Offset> pebbles = [];

  /// (position, bright-or-dark, size) tiny dots for ground grain.
  final List<(Offset, int, double)> specks = [];
  final List<_Spot> blobs = [];

  /// (x, y, z, brightness) unit vectors pointing up into the sky.
  final List<(double, double, double, double)> stars = [];
}

/// Third-person lunar scene: the camera floats behind the astronaut, the
/// ground falls away to a star-field horizon. Everything is drawn with a
/// simple perspective projection onto the 2D canvas.
class LunarScenePainter extends CustomPainter {
  LunarScenePainter({
    required this.scenery,
    required this.astronaut,
    required this.altitude,
    required this.heading,
    required this.camYaw,
    required this.moving,
    required this.time,
    required this.particles,
    this.target,
    this.pads = const [],
    this.heritage = const [],
    this.activePad = -1,
    this.buildingPad = -1,
    this.buildProgress = 0,
    this.visibleCount = 99,
    this.builtCount = 0,
    this.day = 1,
    this.suitAccent = const Color(0xFF45E6FF),
  });

  final LunarScenery scenery;

  /// Astronaut position on the ground plane (x, z).
  final Offset astronaut;

  /// Jump altitude above the terrain.
  final double altitude;
  final double heading;

  /// Smoothed camera yaw (lags the heading so turning feels soft).
  final double camYaw;
  final bool moving;
  final double time;
  final List<DustParticle> particles;

  /// Where the glowing beacon and the edge arrow point (null = none).
  final Offset? target;

  /// Build pads (one per decision option), the pad you stand on, and the
  /// pad that is currently being built (0..1 progress).
  final List<BuildPad> pads;

  /// Structures finished on earlier mission days: drawn already built so the
  /// colony grows across the whole adventure.
  final List<BuildPad> heritage;
  final int activePad;
  final int buildingPad;
  final double buildProgress;

  /// Only the first [visibleCount] pads are shown; the first [builtCount] of
  /// those are finished habitats that stay on the Moon.
  final int visibleCount;
  final int builtCount;

  /// Mission day: colours the ambience and adds day-specific scenery props.
  final int day;

  /// The astronaut's suit accent colour from the character selection.
  final Color suitAccent;

  static const double worldRadius = 90;
  static const Offset lander = Offset.zero;
  static const double landerPadRadius = 7;

  /// Landmarks of the outpost.
  static const Offset baseDome = Offset(-30, -35);
  static const Offset antenna = Offset(-22, -31);
  static const Offset door = Offset(0, 3.8);

  // Camera rig: behind and above the astronaut, looking slightly ahead.
  late double _cx, _cy, _cz;
  late double _fx, _fy, _fz;
  late double _rx, _ry, _rz;
  late double _ux, _uy, _uz;
  late double _focal;
  late Size _size;

  void _buildCamera() {
    final dx = math.sin(camYaw);
    final dz = math.cos(camYaw);
    _cx = astronaut.dx - dx * 7.5;
    _cy = 2.9;
    _cz = astronaut.dy - dz * 7.5;
    // Look at a point in front of the astronaut's chest.
    final tx = astronaut.dx + dx * 4.5;
    final ty = 1.1;
    final tz = astronaut.dy + dz * 4.5;
    var fx = tx - _cx, fy = ty - _cy, fz = tz - _cz;
    final fl = math.sqrt(fx * fx + fy * fy + fz * fz);
    fx /= fl;
    fy /= fl;
    fz /= fl;
    // The world is x = right, y = up, z = forward (heading 0 looks along +z),
    // so right = normalise(cross(worldUp, forward)) = (fz, 0, -fx).
    var rx = fz;
    var ry = 0.0;
    var rz = -fx;
    final rl = math.sqrt(rx * rx + ry * ry + rz * rz);
    rx /= rl;
    ry /= rl;
    rz /= rl;
    // up = cross(forward, right)
    _ux = fy * rz - fz * ry;
    _uy = fz * rx - fx * rz;
    _uz = fx * ry - fy * rx;
    _fx = fx;
    _fy = fy;
    _fz = fz;
    _rx = rx;
    _ry = ry;
    _rz = rz;
    // ~55 degree vertical field of view.
    _focal = (_size.height / 2) / math.tan(55 * math.pi / 360);
  }

  /// Projects a world point to the screen; null when behind the camera.
  Offset? _proj(double x, double y, double z) {
    final dx = x - _cx, dy = y - _cy, dz = z - _cz;
    final zc = dx * _fx + dy * _fy + dz * _fz;
    if (zc < 0.5) return null;
    final xc = dx * _rx + dy * _ry + dz * _rz;
    final yc = dx * _ux + dy * _uy + dz * _uz;
    return Offset(
      _size.width / 2 + xc * _focal / zc,
      _size.height / 2 - yc * _focal / zc,
    );
  }

  /// Projects a sky direction (unit vector, no translation).
  Offset? _projDir(double x, double y, double z) {
    final zc = x * _fx + y * _fy + z * _fz;
    if (zc < 0.05) return null;
    final xc = x * _rx + y * _ry + z * _rz;
    final yc = x * _ux + y * _uy + z * _uz;
    return Offset(
      _size.width / 2 + xc * _focal / zc,
      _size.height / 2 - yc * _focal / zc,
    );
  }

  /// Depth of a point along the view axis (for fading far objects).
  double _depth(double x, double y, double z) {
    return (x - _cx) * _fx + (y - _cy) * _fy + (z - _cz) * _fz;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _size = size;
    _buildCamera();

    // Horizon: project a far-away ground point straight ahead.
    final horizon =
        _projDir(_fx, 0, _fz) ?? Offset(size.width / 2, size.height * 0.35);
    final horizonY = horizon.dy.clamp(0.0, size.height * 0.9);

    _drawSky(canvas, size, horizonY);
    _drawGround(canvas, size, horizonY);
    _drawWorld(canvas, size, horizonY);
    _drawDayExtras(canvas);
    _drawLandmarks(canvas);
    _drawPads(canvas);
    _drawBeacon(canvas);
    _drawLander(canvas);
    _drawParticles(canvas);
    _drawAstronaut(canvas);
    _drawAmbience(canvas, size);
    _drawEdgeCue(canvas, size);
  }

  /// A soft colour wash over the whole frame: solar storms glow violet,
  /// the emergency day flashes red, the ice day feels colder.
  void _drawAmbience(Canvas canvas, Size size) {
    final color = switch (day) {
      3 => const Color(0xFF8E5BFF),
      5 => const Color(0xFFFF4D5A),
      4 => const Color(0xFF42A5F5),
      6 => const Color(0xFF66BB6A),
      _ => const Color(0x00000000),
    };
    if (color.a == 0) return;
    final pulse = day == 5 ? (math.sin(time * 3) + 1) / 2 : 0.5;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withAlpha((10 + 18 * pulse).round()), color.withAlpha(0)],
        ).createShader(Offset.zero & size),
    );
  }

  /// Extra scenery that makes every day look different.
  void _drawDayExtras(Canvas canvas) {
    switch (day) {
      case 2:
        // Solar panel field: rows of blue panels tilted at the Sun.
        for (var i = 0; i < 4; i++) {
          _drawSolarPanel(canvas, Offset(18 + i * 7, -34 - (i.isOdd ? 3 : 0)));
        }
        break;
      case 4:
        // Blue ice crystals sparkling in the dark.
        for (var i = 0; i < 6; i++) {
          _drawCrystal(canvas, Offset(12 + i * 11, -14 - (i % 3) * 9));
        }
        break;
      case 5:
        // Meteorite impact site: scorched crater with drifting smoke.
        _drawImpactSite(canvas);
        break;
      case 6:
        // Greenhouse dome glowing green next to the base.
        _drawGreenhouse(canvas);
        break;
      case 7:
        // Rare glowing mineral veins near the science station.
        for (var i = 0; i < 3; i++) {
          _drawCrystal(canvas, Offset(26 + i * 6, 18 + (i % 2) * 7));
        }
        break;
    }
  }

  void _drawSolarPanel(Canvas canvas, Offset pos) {
    final y = scenery.terrainAt(pos.dx, pos.dy);
    final p = _proj(pos.dx, y + 1.2, pos.dy);
    final base = _proj(pos.dx, y, pos.dy);
    if (p == null || base == null) return;
    final s = _focal / _depth(pos.dx, 0, pos.dy);
    canvas.drawLine(base, p, Paint()..color = const Color(0xFF7E8298)..strokeWidth = math.max(1, s * 0.06));
    final w = 3.0 * s, h = 1.5 * s;
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: p, width: w, height: h), Radius.circular(0.15 * s));
    canvas.drawRRect(r, Paint()..color = const Color(0xFF1C4FA0));
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, s * 0.05)
        ..color = const Color(0xFF5CC8FF),
    );
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(Offset(p.dx - w / 2 + w * i / 3, p.dy - h / 2), Offset(p.dx - w / 2 + w * i / 3, p.dy + h / 2),
          Paint()..color = const Color(0x665CC8FF)..strokeWidth = 1);
    }
  }

  void _drawCrystal(Canvas canvas, Offset pos) {
    final y = scenery.terrainAt(pos.dx, pos.dy);
    final base = _proj(pos.dx, y, pos.dy);
    final top = _proj(pos.dx, y + 1.6, pos.dy);
    if (base == null || top == null) return;
    final s = _focal / _depth(pos.dx, 0, pos.dy);
    final w = 0.5 * s;
    final glint = (math.sin(time * 2.5 + pos.dx) + 1) / 2;
    final shard = Path()
      ..moveTo(base.dx - w, base.dy)
      ..lineTo(base.dx + w, base.dy)
      ..lineTo(top.dx + w * 0.3, top.dy + w)
      ..lineTo(top.dx, top.dy)
      ..lineTo(top.dx - w * 0.3, top.dy + w)
      ..close();
    canvas.drawPath(shard, Paint()..color = Color.fromRGBO(69, 230, 255, 0.35 + glint * 0.4));
    canvas.drawPath(
      shard,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, s * 0.04)
        ..color = const Color(0xFF45E6FF),
    );
  }

  void _drawImpactSite(Canvas canvas) {
    const pos = Offset(16, 12);
    final y = scenery.terrainAt(pos.dx, pos.dy);
    final base = _proj(pos.dx, y, pos.dy);
    if (base == null) return;
    final s = _focal / _depth(pos.dx, 0, pos.dy);
    final ring = _projectGroundRing(pos, 4.5, 12);
    if (ring != null) {
      canvas.drawPath(ring, Paint()..color = const Color(0xBB2A1A1E));
      canvas.drawPath(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFFF4D5A),
      );
    }
    // Smoke columns rising from the wreck.
    for (var i = 0; i < 3; i++) {
      final drift = math.sin(time * 1.4 + i * 2.1) * 0.4;
      final p = _proj(pos.dx - 1 + i, y + 1.5 + i * 1.6, pos.dy + drift);
      if (p == null) continue;
      canvas.drawCircle(p, s * (0.5 + i * 0.35), Paint()..color = Color.fromRGBO(90, 90, 110, 0.4 - i * 0.1));
    }
    // Blinking emergency beacon.
    final blink = (math.sin(time * 6) + 1) / 2;
    canvas.drawCircle(base + Offset(0, -1.8 * s), math.max(2, s * 0.1) * (0.5 + blink),
        Paint()..color = const Color(0xFFFF4D5A));
  }

  void _drawGreenhouse(Canvas canvas) {
    const pos = Offset(-42, -18);
    final y = scenery.terrainAt(pos.dx, pos.dy);
    final base = _proj(pos.dx, y, pos.dy);
    if (base == null) return;
    final s = _focal / _depth(pos.dx, 0, pos.dy);
    final dome = Rect.fromCenter(center: base, width: 6 * s, height: 2 * 2.6 * s);
    // Green plants inside.
    for (var i = 0; i < 3; i++) {
      final gx = base.dx - 1.8 * s + i * 1.8 * s;
      canvas.drawOval(Rect.fromCenter(center: Offset(gx, base.dy - 0.4 * s), width: 1.1 * s, height: 0.8 * s),
          Paint()..color = const Color(0xFF66BB6A));
    }
    canvas.drawArc(dome, math.pi, math.pi, true, Paint()..color = const Color(0x4466BB6A));
    canvas.drawArc(
      dome,
      math.pi,
      math.pi,
      true,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, s * 0.06)
        ..color = const Color(0xFF9BE37A),
    );
  }

  void _drawSky(Canvas canvas, Size size, double horizonY) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, horizonY + 2),
      Paint()..color = const Color(0xFF04050D),
    );
    // Stars twinkle gently.
    final starPaint = Paint();
    for (var i = 0; i < scenery.stars.length; i++) {
      final s = scenery.stars[i];
      final p = _projDir(s.$1, s.$2, s.$3);
      if (p == null) continue;
      final tw = 0.55 + 0.45 * math.sin(time * 1.5 + i * 1.7);
      starPaint.color =
          Color.fromRGBO(255, 255, 255, (0.35 + s.$4 * 0.65) * tw);
      canvas.drawCircle(p, s.$4 * 1.6, starPaint);
    }
    // Earth hangs in the sky, like in the trainer.
    final earth = _projDir(0.42, 0.52, -0.55);
    if (earth != null) {
      final r = 26.0;
      canvas.drawCircle(earth, r + 5, Paint()..color = const Color(0x331A66CC));
      canvas.drawCircle(earth, r, Paint()..color = const Color(0xFF1C5FC4));
      canvas.drawCircle(earth + const Offset(-6, -5), r * 0.28,
          Paint()..color = const Color(0x883CC86E));
      canvas.drawCircle(earth + const Offset(9, 4), r * 0.2,
          Paint()..color = const Color(0x663CC86E));
      canvas.drawCircle(earth + const Offset(2, -10), r * 0.14,
          Paint()..color = const Color(0x77FFFFFF));
    }
  }

  void _drawGround(Canvas canvas, Size size, double horizonY) {
    final rect = Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9C9CA8), Color(0xFF73737F), Color(0xFF8C8C98)],
        ).createShader(rect),
    );
    // Dust haze hugging the horizon.
    final haze = Rect.fromLTWH(0, horizonY - 6, size.width, 30);
    canvas.drawRect(
      haze,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF9C9CA8).withAlpha(160),
            const Color(0xFF9C9CA8).withAlpha(0)
          ],
        ).createShader(haze),
    );
    // Distant crater-rim hills along the horizon; they slide as you turn.
    final ridge = Path()..moveTo(-4, horizonY + 10);
    for (var i = 0; i <= 48; i++) {
      final x = i * (size.width + 8) / 48 - 4;
      final t = i * 0.55 + camYaw * 3;
      final h = (math.sin(t) * 3.5 + math.sin(t * 0.37 + 1.7) * 5.5).abs();
      ridge.lineTo(x, horizonY + 8 - h);
    }
    ridge
      ..lineTo(size.width + 4, horizonY + 10)
      ..close();
    canvas.drawPath(ridge, Paint()..color = const Color(0xFF7E7E8C));
    // Soft light/dark mottling patches on the ground.
    for (final blob in scenery.blobs) {
      if ((blob.pos - astronaut).distance > 90) continue;
      final ring = _projectGroundRing(blob.pos, blob.size, 8);
      if (ring == null) continue;
      canvas.drawPath(
        ring,
        Paint()
          ..color =
              blob.size > 9 ? const Color(0x14FFFFFF) : const Color(0x10FFFFFF),
      );
    }
    // Fine grain so the plain looks like real dusty regolith.
    final speckPaint = Paint();
    for (final (pos, sign, s0) in scenery.specks) {
      if ((pos - astronaut).distance > 55) continue;
      final p = _proj(pos.dx, scenery.terrainAt(pos.dx, pos.dy) + 0.03, pos.dy);
      if (p == null) continue;
      final z = _depth(pos.dx, 0, pos.dy);
      final r = (_focal / z) * s0;
      speckPaint.color = sign > 0
          ? Color.fromRGBO(200, 202, 214, 0.35)
          : Color.fromRGBO(60, 60, 74, 0.4);
      canvas.drawCircle(p, r.clamp(0.4, 2.2), speckPaint);
    }
  }

  /// Projects a circle lying on the terrain as an n-gon; null if clipped.
  Path? _projectGroundRing(Offset center, double radius, int n) {
    final path = Path();
    for (var i = 0; i <= n; i++) {
      final a = i * 2 * math.pi / n;
      final x = center.dx + math.cos(a) * radius;
      final z = center.dy + math.sin(a) * radius;
      final p = _proj(x, scenery.terrainAt(x, z), z);
      if (p == null) return null;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  void _drawWorld(Canvas canvas, Size size, double horizonY) {
    // Fade factor for distant features.
    double fade(double z) => (1 - ((z - 25) / 75)).clamp(0.12, 1.0);

    // Craters far to near so nearer ones overlap correctly.
    final craters = scenery.craters
        .where((c) => (c.pos - astronaut).distance < 110)
        .toList()
      ..sort((a, b) => _depth(b.pos.dx, 0, b.pos.dy)
          .compareTo(_depth(a.pos.dx, 0, a.pos.dy)));
    for (final c in craters) {
      final z = _depth(c.pos.dx, 0, c.pos.dy);
      final ring = _projectGroundRing(c.pos, c.size, 10);
      if (ring == null) continue;
      canvas.drawPath(
          ring, Paint()..color = Color.fromRGBO(70, 70, 84, 0.85 * fade(z)));
      canvas.drawPath(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Color.fromRGBO(210, 212, 226, 0.4 * fade(z)),
      );
      // Dark floor slightly inset.
      final floor = _projectGroundRing(c.pos, c.size * 0.62, 10);
      if (floor != null) {
        canvas.drawPath(
            floor, Paint()..color = Color.fromRGBO(54, 54, 68, 0.7 * fade(z)));
      }
    }

    // Pebbles: tiny ground dots near the astronaut only.
    final pebblePaint = Paint();
    for (final p in scenery.pebbles) {
      if ((p - astronaut).distance > 45) continue;
      final s = _proj(p.dx, scenery.terrainAt(p.dx, p.dy) + 0.02, p.dy);
      if (s == null) continue;
      final z = _depth(p.dx, 0, p.dy);
      final r = (_focal / z) * 0.06;
      pebblePaint.color = Color.fromRGBO(60, 60, 72, 0.8 * fade(z));
      canvas.drawCircle(s, r.clamp(0.6, 3.5), pebblePaint);
    }

    // Rocks far to near.
    final rocks = scenery.rocks
        .where((r) => (r.pos - astronaut).distance < 90)
        .toList()
      ..sort((a, b) => _depth(b.pos.dx, 0, b.pos.dy)
          .compareTo(_depth(a.pos.dx, 0, a.pos.dy)));
    for (final rock in rocks) {
      final z = _depth(rock.pos.dx, 0, rock.pos.dy);
      final f = fade(z);
      // Three-point silhouette: base left/right on the ground, apex above.
      final right = Offset(_rx, _rz);
      final side = right * rock.size;
      final baseY = scenery.terrainAt(rock.pos.dx, rock.pos.dy);
      final bl = _proj(rock.pos.dx - side.dx, baseY, rock.pos.dy - side.dy);
      final br = _proj(rock.pos.dx + side.dx, baseY, rock.pos.dy + side.dy);
      final top = _proj(rock.pos.dx, baseY + rock.size * 1.7, rock.pos.dy);
      final mid = _proj(rock.pos.dx, baseY, rock.pos.dy);
      if (bl == null || br == null || top == null || mid == null) continue;
      final path = Path()
        ..moveTo(bl.dx, bl.dy)
        ..lineTo(top.dx, top.dy)
        ..lineTo(br.dx, br.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = Color.fromRGBO(126, 126, 142, f));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Color.fromRGBO(70, 70, 84, f),
      );
      // Lit top face.
      final hl = Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(mid.dx, mid.dy)
        ..lineTo(br.dx, br.dy)
        ..close();
      canvas.drawPath(
          hl, Paint()..color = Color.fromRGBO(160, 160, 176, 0.5 * f));
    }
  }

  void _drawBeacon(Canvas canvas) {
    final stop = target;
    if (stop == null) return;
    // Pillar of light rising from the target.
    final stopY = scenery.terrainAt(stop.dx, stop.dy);
    final base = _proj(stop.dx, stopY, stop.dy);
    final top = _proj(stop.dx, stopY + 14, stop.dy);
    if (base == null || top == null) return;
    final w =
        (base.dx - top.dx).abs() + _focal / _depth(stop.dx, 0, stop.dy) * 1.1;
    final beam = Path()
      ..moveTo(base.dx - w, base.dy)
      ..lineTo(base.dx + w, base.dy)
      ..lineTo(top.dx + w * 0.12, top.dy)
      ..lineTo(top.dx - w * 0.12, top.dy)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            GameColors.yellow.withAlpha(110),
            GameColors.yellow.withAlpha(0)
          ],
        ).createShader(
            Rect.fromLTWH(base.dx - w, top.dy, w * 2, base.dy - top.dy)),
    );
    // Ground ring + pulse.
    final pulse = (math.sin(time * 3) + 1) / 2;
    final ring = _projectGroundRing(stop, 1.6 + pulse * 0.5, 12);
    if (ring != null) {
      canvas.drawPath(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = GameColors.yellow,
      );
    }
    canvas.drawCircle(
      base,
      5 + pulse * 2,
      Paint()..color = GameColors.yellow.withAlpha(220),
    );
  }

  /// Distant outpost like the trainer: a white base dome, an antenna mast
  /// with a dish, and a flag planted at the old landing marker.
  static const Offset _baseDome = baseDome;
  static const Offset _antenna = antenna;

  void _drawLandmarks(Canvas canvas) {
    // Base dome: a half sphere sitting on the ground.
    final domeBase = _proj(_baseDome.dx,
        scenery.terrainAt(_baseDome.dx, _baseDome.dy), _baseDome.dy);
    if (domeBase != null) {
      final z = _depth(_baseDome.dx, 0, _baseDome.dy);
      final s = _focal / z;
      final rect = Rect.fromCenter(
        center: domeBase + Offset(0, -1.4 * s),
        width: 8.4 * s,
        height: 5.6 * s,
      );
      canvas.drawArc(
        rect,
        math.pi,
        math.pi,
        true,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Color(0xFFF2F4FC), Color(0xFFB9BCCB)],
          ).createShader(rect),
      );
      // Airlock door.
      final doorW = 0.9 * s;
      canvas.drawRect(
        Rect.fromLTWH(
            domeBase.dx - doorW / 2, domeBase.dy - 1.7 * s, doorW, 1.7 * s),
        Paint()..color = const Color(0xFF3A4056),
      );
      canvas.drawCircle(
        domeBase + Offset(0, -2.6 * s),
        0.18 * s,
        Paint()..color = const Color(0xFF7FD0FF),
      );
    }

    // Antenna mast with a dish and a blinking lamp.
    final antBase = _proj(
        _antenna.dx, scenery.terrainAt(_antenna.dx, _antenna.dy), _antenna.dy);
    if (antBase != null) {
      final z = _depth(_antenna.dx, 0, _antenna.dy);
      final s = _focal / z;
      final mastPaint = Paint()
        ..color = const Color(0xFF8A8AA0)
        ..strokeWidth = math.max(1.5, s * 0.05);
      final top = antBase + Offset(0, -4.2 * s);
      canvas.drawLine(antBase, top, mastPaint);
      // Dish.
      canvas.drawOval(
        Rect.fromCenter(
            center: antBase + Offset(0.3 * s, -3.9 * s),
            width: 1.5 * s,
            height: 1.0 * s),
        Paint()..color = const Color(0xFFE6E8F2),
      );
      canvas.drawOval(
        Rect.fromCenter(
            center: antBase + Offset(0.3 * s, -3.9 * s),
            width: 0.5 * s,
            height: 0.3 * s),
        Paint()..color = const Color(0xFF9AA0BC),
      );
      final blink = (math.sin(time * 4) + 1) / 2;
      canvas.drawCircle(
        top + Offset(0, -0.2 * s),
        math.max(2, s * 0.08),
        Paint()..color = Color.fromRGBO(255, 70, 70, 0.4 + blink * 0.6),
      );
      // Solar panels either side of the mast.
      for (final side in [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(antBase.dx + side * 1.8 * s, antBase.dy - 1.2 * s);
        canvas.rotate(side * 0.35);
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: 2.0 * s, height: 0.9 * s),
          Paint()..color = const Color(0xFF1A2F7A),
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: 2.0 * s, height: 0.9 * s),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0xFF5CC8FF),
        );
        canvas.restore();
      }
    }
  }

  /// The build pads: glowing discs on the ground, one per option. The pad
  /// being built grows into a little habitat. Heritage pads are finished
  /// builds from earlier days, drawn already done.
  void _drawPads(Canvas canvas) {
    final items = <({BuildPad pad, bool active, bool done, bool building, bool old})>[
      for (final p in heritage)
        (pad: p, active: false, done: true, building: true, old: true),
      for (var i = 0; i < pads.length && i < visibleCount; i++)
        (
          pad: pads[i],
          active: i == activePad,
          done: i < builtCount,
          building: i == buildingPad || i < builtCount,
          old: false,
        ),
    ]..sort((a, b) => _depth(b.pad.pos.dx, 0, b.pad.pos.dy)
        .compareTo(_depth(a.pad.pos.dx, 0, a.pad.pos.dy)));
    for (final item in items) {
      final pad = item.pad;
      final p = pad.pos;
      final y = scenery.terrainAt(p.dx, p.dy);
      final base = _proj(p.dx, y, p.dy);
      if (base == null) continue;
      final z = _depth(p.dx, 0, p.dy);
      if (z < 1) continue;
      final s = _focal / z;
      final active = item.active;
      final done = item.done;
      final building = item.building;

      final disc = _projectGroundRing(p, 2.4, 18);
      if (disc != null) {
        canvas.drawPath(disc,
            Paint()
              ..color = pad.color
                  .withAlpha(item.old ? 40 : (active || building ? 95 : 45)));
        canvas.drawPath(
          disc,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = active ? 4 : 2.5
            ..color = pad.color.withAlpha(active ? 255 : (item.old ? 110 : 190)),
        );
      }

      double labelHeight = 6.8;
      if (building) {
        // The structure that belongs to this objective grows out of the pad.
        final k = done ? 1.0 : buildProgress.clamp(0.0, 1.0);
        _drawBuiltThing(canvas, base, s, pad, k);
        // Welding sparks while it is still going up.
        if (!done) {
          final spark = (math.sin(time * 40) + 1) / 2;
          canvas.drawCircle(
            Offset(base.dx + 1.9 * s, base.dy - 2 * s * k),
            math.max(2, s * 0.12) * (0.6 + spark),
            Paint()..color = const Color(0xFFFFD35E),
          );
        }
        labelHeight = 4.6;
      } else {
        final top = _proj(p.dx, y + 6, p.dy);
        if (top != null) {
          final w = s * 0.5;
          final beam = Path()
            ..moveTo(base.dx - w, base.dy)
            ..lineTo(base.dx + w, base.dy)
            ..lineTo(top.dx + w * 0.2, top.dy)
            ..lineTo(top.dx - w * 0.2, top.dy)
            ..close();
          canvas.drawPath(
            beam,
            Paint()
              ..blendMode = BlendMode.plus
              ..shader = LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  pad.color.withAlpha(active ? 150 : 90),
                  pad.color.withAlpha(0)
                ],
              ).createShader(Rect.fromLTWH(
                  base.dx - w, top.dy, w * 2, (base.dy - top.dy).abs() + 1)),
          );
          // Floating action icon above the beam: collect, scan, repair...
          if (z < 60) {
            final iconPaint = TextPainter(
              text: TextSpan(
                text: String.fromCharCode(pad.kind.icon.codePoint),
                style: TextStyle(
                  fontFamily: pad.kind.icon.fontFamily,
                  package: pad.kind.icon.fontPackage,
                  color: active ? pad.color : pad.color.withAlpha(180),
                  fontSize: (s * 0.8).clamp(15.0, 30.0),
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            final bob = math.sin(time * 2.4) * 3;
            iconPaint.paint(
              canvas,
              Offset(top.dx - iconPaint.width / 2, top.dy - iconPaint.height - 4 + bob),
            );
          }
        }
      }

      // Name tag floating over the pad.
      final tag = _proj(p.dx, y + labelHeight, p.dy);
      if (!done && tag != null && z < 60) {
        final tp = TextPainter(
          text: TextSpan(
            text: pad.label,
            style: TextStyle(
              color: Colors.white,
              fontSize: (s * 0.5).clamp(10.0, 17.0),
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 2,
          textAlign: TextAlign.center,
        )..layout(maxWidth: 170);
        final rect = Rect.fromCenter(
            center: tag, width: tp.width + 16, height: tp.height + 8);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(10)),
          Paint()..color = const Color(0xCC0A1238),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(10)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = active ? 2.5 : 1.5
            ..color = pad.color,
        );
        tp.paint(canvas, Offset(rect.left + 8, rect.top + 4));
      }
    }
  }

  /// The structure that grows out of a pad, drawn to match the objective's
  /// interaction kind: a habitat, a mast, a panel, a crate, a radar...
  void _drawBuiltThing(Canvas canvas, Offset base, double s, BuildPad pad, double k) {
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, s * 0.05)
      ..color = pad.color;
    final w = 3.4 * s;
    final hBody = 2.0 * s * k;
    final body = Rect.fromLTWH(base.dx - w / 2, base.dy - hBody, w, hBody);
    canvas.drawRect(body, Paint()..color = const Color(0xFFD8DAE4));
    canvas.drawRect(body, outline);
    switch (pad.kind) {
      case InteractKind.build:
        // Dome roof appears during the second half of the build.
        if (k > 0.5) {
          final dk = (k - 0.5) * 2;
          final dome = Rect.fromCenter(center: Offset(base.dx, base.dy - hBody), width: w, height: 2 * 1.5 * s * dk);
          canvas.drawArc(dome, math.pi, math.pi, true, Paint()..color = const Color(0xFFF2F4FC));
          canvas.drawArc(dome, math.pi, math.pi, true, outline);
        }
        break;
      case InteractKind.install:
        // Mast with a small dish on top.
        final top = Offset(base.dx, base.dy - hBody - 1.6 * s * k);
        canvas.drawLine(Offset(base.dx, base.dy - hBody), top, outline..strokeWidth = math.max(1.5, s * 0.07));
        canvas.drawCircle(top, 0.3 * s * k, outline);
        break;
      case InteractKind.activate:
        // Switch box with a glowing power light.
        canvas.drawCircle(
          Offset(base.dx, base.dy - hBody - 0.5 * s * k),
          0.45 * s * k,
          Paint()..color = Color.fromRGBO(255, 211, 94, 0.35 + 0.45 * ((math.sin(time * 5) + 1) / 2)),
        );
        canvas.drawCircle(Offset(base.dx, base.dy - hBody - 0.5 * s * k), 0.2 * s * k, Paint()..color = pad.color);
        break;
      case InteractKind.repair:
        // Scaffold frame around the unit.
        for (final dx in [-w / 2 - 0.2 * s, w / 2 + 0.2 * s]) {
          canvas.drawLine(Offset(base.dx + dx, base.dy), Offset(base.dx + dx, base.dy - hBody - 0.6 * s * k), outline);
        }
        canvas.drawLine(Offset(base.dx - w / 2 - 0.2 * s, base.dy - hBody - 0.6 * s * k),
            Offset(base.dx + w / 2 + 0.2 * s, base.dy - hBody - 0.6 * s * k), outline);
        break;
      case InteractKind.collect:
        // Stacked supply crates instead of a tall unit.
        for (var i = 0; i < 2; i++) {
          final cw = w * (1 - i * 0.3);
          final r = Rect.fromLTWH(base.dx - cw / 2, base.dy - hBody * (i + 1) / 2, cw, hBody / 2);
          canvas.drawRect(r, Paint()..color = const Color(0xFFB8BCC8));
          canvas.drawRect(r, outline);
        }
        canvas.drawRect(Rect.fromLTWH(base.dx - 0.05 * s, base.dy - hBody - 1.2 * s * k, 0.1 * s, 1.2 * s * k),
            Paint()..color = const Color(0xFFEEEEEE));
        canvas.drawRect(Rect.fromLTWH(base.dx + 0.05 * s, base.dy - hBody - 1.15 * s * k, 0.8 * s * k, 0.5 * s * k),
            Paint()..color = pad.color);
        break;
      case InteractKind.scan:
        // Rotating radar dish above the unit.
        final center = Offset(base.dx, base.dy - hBody - 0.4 * s * k);
        final ang = time * 1.5;
        canvas.drawLine(center,
            Offset(center.dx + math.cos(ang) * 0.9 * s * k, center.dy - math.sin(ang).abs() * 0.5 * s * k), outline);
        canvas.drawCircle(center, 0.22 * s * k, Paint()..color = pad.color);
        break;
      case InteractKind.explore:
        // Survey flag and a small marker stone.
        canvas.drawLine(Offset(base.dx, base.dy), Offset(base.dx, base.dy - hBody - 1.1 * s * k),
            Paint()..color = const Color(0xFFEEEEEE)..strokeWidth = math.max(1.5, s * 0.06));
        canvas.drawRect(Rect.fromLTWH(base.dx, base.dy - hBody - 1.1 * s * k, 1.1 * s * k, 0.65 * s * k),
            Paint()..color = pad.color);
        canvas.drawCircle(Offset(base.dx - w * 0.4, base.dy - 0.2 * s), 0.25 * s, Paint()..color = const Color(0xFF8A8E9E));
        break;
    }
  }

  void _drawLander(Canvas canvas) {
    final base =
        _proj(lander.dx, scenery.terrainAt(lander.dx, lander.dy), lander.dy);
    if (base == null) return;
    final z = _depth(lander.dx, 0, lander.dy);
    if (z < 1) return;
    final s = _focal / z; // px per world unit at that depth
    canvas.save();
    canvas.translate(base.dx, base.dy);
    // Pad ring on the ground.
    final pad = _projectGroundRing(lander, landerPadRadius, 16);
    canvas.restore();
    if (pad != null) {
      canvas.drawPath(
        pad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = GameColors.green.withAlpha(190),
      );
    }
    canvas.save();
    canvas.translate(base.dx, base.dy);
    // Legs splaying out on the ground.
    final legPaint = Paint()
      ..color = const Color(0xFF8A8A99)
      ..strokeWidth = math.max(2, s * 0.06)
      ..strokeCap = StrokeCap.round;
    for (final dx in [-1.0, 1.0]) {
      canvas.drawLine(
          Offset(dx * 0.7 * s, -0.4 * s), Offset(dx * 2.4 * s, 0), legPaint);
    }
    // Gold foil body.
    final w = 1.5 * s;
    final h = 1.9 * s;
    final body = Path()
      ..moveTo(-w * 0.55, -h)
      ..lineTo(w * 0.55, -h)
      ..lineTo(w, -h * 0.35)
      ..lineTo(-w, -h * 0.35)
      ..close();
    canvas.drawPath(body, Paint()..color = const Color(0xFFD8B44A));
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, s * 0.04)
        ..color = const Color(0xFF8A6A1E),
    );
    // Green door with a little ramp, like the trainer's spaceship.
    canvas.drawRect(
      Rect.fromLTWH(-0.3 * s, -h * 0.35 - 0.95 * s, 0.6 * s, 0.95 * s),
      Paint()..color = const Color(0xFF30C060),
    );
    canvas.drawLine(
      Offset(0, -h * 0.35),
      Offset(0, 0.9 * s),
      Paint()
        ..color = const Color(0xFF555A6E)
        ..strokeWidth = math.max(2, s * 0.35),
    );
    // Crew capsule on top + antenna + blinking light.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-w * 0.4, -h - 0.55 * s, w * 0.8, 0.55 * s),
        Radius.circular(0.08 * s),
      ),
      Paint()..color = const Color(0xFFCFCFD8),
    );
    canvas.drawLine(
        Offset(0, -h - 0.55 * s), Offset(0, -h - 1.5 * s), legPaint);
    final blink = (math.sin(time * 4) + 1) / 2;
    canvas.drawCircle(
      Offset(0, -h - 1.6 * s),
      math.max(2.5, s * 0.09),
      Paint()..color = Color.fromRGBO(255, 70, 70, 0.4 + blink * 0.6),
    );
    canvas.restore();
  }

  void _drawParticles(Canvas canvas) {
    final paint = Paint();
    for (final p in particles) {
      final s = _proj(p.x, scenery.terrainAt(p.x, p.z) + 0.25, p.z);
      if (s == null) continue;
      final alpha = (p.life / DustParticle.maxLife).clamp(0.0, 1.0);
      paint.color = Color.fromRGBO(190, 190, 202, 0.5 * alpha);
      canvas.drawCircle(s, 2 + (1 - alpha) * 2.5, paint);
    }
  }

  void _drawAstronaut(Canvas canvas) {
    final groundY = scenery.terrainAt(astronaut.dx, astronaut.dy);
    final feet = _proj(astronaut.dx, groundY + altitude, astronaut.dy);
    if (feet == null) return;
    final z = _depth(astronaut.dx, 0, astronaut.dy);
    final s = _focal / z; // px per world unit

    // Soft ground shadow.
    final shadow = _projectGroundRing(astronaut, 0.55, 8);
    if (shadow != null) {
      canvas.drawPath(shadow, Paint()..color = Colors.black.withAlpha(80));
    }
    paintAstronautSprite(canvas, feet, s,
        moving: moving, time: time, altitude: altitude, accent: suitAccent);
  }

  /// Arrow at the screen edge when the target is behind or out of view.
  void _drawEdgeCue(Canvas canvas, Size size) {
    final stop = target;
    if (stop == null) return;
    final p =
        _proj(stop.dx, scenery.terrainAt(stop.dx, stop.dy) + 0.5, stop.dy);
    const margin = 40.0;
    if (p != null &&
        p.dx > margin &&
        p.dx < size.width - margin &&
        p.dy > margin &&
        p.dy < size.height - margin) {
      return;
    }
    // Direction to the stop in camera space.
    final dx = stop.dx - _cx, dz = stop.dy - _cz;
    final side = dx * _rx + dz * _rz;
    final ahead = dx * _fx + dz * _fz;
    final screenX = ahead >= 0
        ? (side > 0 ? size.width - margin : margin)
        : (side > 0 ? margin : size.width - margin);
    final arrow = Path()
      ..moveTo(14, 0)
      ..lineTo(-8, -9)
      ..lineTo(-8, 9)
      ..close();
    canvas.save();
    canvas.translate(screenX, size.height * 0.45);
    canvas.rotate(ahead >= 0
        ? (side > 0 ? 0 : math.pi)
        : (side > 0 ? -math.pi / 2 : math.pi / 2));
    canvas.drawPath(arrow, Paint()..color = GameColors.yellow.withAlpha(220));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LunarScenePainter oldDelegate) => true;
}

/// The astronaut seen from behind, feet at [feet], [s] pixels per world unit.
/// Shared by the Moon surface and the spaceship interior.
void paintAstronautSprite(
  Canvas canvas,
  Offset feet,
  double s, {
  required bool moving,
  required double time,
  required double altitude,
  Color accent = const Color(0xFF45E6FF),
}) {
  canvas.save();
  canvas.translate(feet.dx, feet.dy);
  final suit = Paint()..color = const Color(0xFFF4F4F8);
  final suitShade = Paint()..color = const Color(0xFFD8DAE4);
  final dark = Paint()..color = const Color(0xFF555A6E);
  final bob = moving ? math.sin(time * 11) * 0.05 * s : 0.0;
  canvas.translate(0, bob);

  // Legs swinging as it walks (seen from behind): white suit legs, dark boots.
  final swing = moving ? math.sin(time * 11) * 0.16 * s : 0.0;
  for (final side in [-1.0, 1.0]) {
    canvas.save();
    canvas.translate(side * 0.16 * s + side * swing * 0.4, -0.55 * s);
    canvas.rotate(side * swing / (s * 2));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-0.1 * s, 0, 0.2 * s, 0.5 * s),
          Radius.circular(0.08 * s)),
      suit,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-0.12 * s, 0.42 * s, 0.24 * s, 0.14 * s),
          Radius.circular(0.05 * s)),
      dark,
    );
    canvas.restore();
  }

  // Arms swinging opposite to the legs.
  for (final side in [-1.0, 1.0]) {
    canvas.save();
    canvas.translate(side * 0.34 * s, -1.28 * s);
    canvas.rotate(-side * swing / (s * 1.6));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-0.09 * s, 0, 0.18 * s, 0.55 * s),
          Radius.circular(0.08 * s)),
      suitShade,
    );
    // Glove.
    canvas.drawCircle(Offset(0, 0.58 * s), 0.09 * s, dark);
    canvas.restore();
  }

  // Torso (white capsule, mostly hidden behind the pack).
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        Rect.fromLTWH(-0.28 * s, -1.15 * s, 0.56 * s, 0.62 * s),
        Radius.circular(0.15 * s)),
    suit,
  );

  // Life-support backpack: the big box every astronaut wears.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        Rect.fromLTWH(-0.34 * s, -1.62 * s, 0.68 * s, 0.9 * s),
        Radius.circular(0.1 * s)),
    Paint()..color = const Color(0xFFB9BCCB),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        Rect.fromLTWH(-0.34 * s, -1.62 * s, 0.68 * s, 0.9 * s),
        Radius.circular(0.1 * s)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, s * 0.03)
      ..color = const Color(0xFF7E8298),
  );
  // Pack details: straps in the chosen suit colour, vents and a status light.
  for (final x in [-0.2 * s, 0.2 * s]) {
    canvas.drawRect(
      Rect.fromLTWH(x - 0.045 * s, -1.62 * s, 0.09 * s, 0.9 * s),
      Paint()..color = Color.lerp(const Color(0xFF9A9FB4), accent, 0.55)!,
    );
  }
  for (var i = 0; i < 3; i++) {
    canvas.drawRect(
      Rect.fromLTWH(-0.12 * s, (-1.05 + i * 0.14) * s, 0.24 * s, 0.05 * s),
      Paint()..color = const Color(0xFF7E8298),
    );
  }
  canvas.drawCircle(Offset(0.24 * s, -1.5 * s), 0.05 * s, Paint()..color = accent);

  // Neck ring + helmet dome.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        Rect.fromLTWH(-0.2 * s, -1.78 * s, 0.4 * s, 0.14 * s),
        Radius.circular(0.05 * s)),
    dark,
  );
  final helmetShine = Paint()
    ..shader = RadialGradient(
      center: const Alignment(-0.35, -0.45),
      radius: 1.1,
      colors: const [Color(0xFFFFFFFF), Color(0xFFE4E6F0), Color(0xFFC2C6D6)],
    ).createShader(
        Rect.fromCircle(center: Offset(0, -1.9 * s), radius: 0.32 * s));
  canvas.drawCircle(Offset(0, -1.9 * s), 0.32 * s, helmetShine);
  // Dark visor band peeking around the front edge of the helmet.
  canvas.drawOval(
    Rect.fromCenter(
        center: Offset(0, -2.0 * s), width: 0.5 * s, height: 0.2 * s),
    Paint()..color = const Color(0xFF14214A),
  );
  // Helmet lamp in the suit's accent colour.
  canvas.drawCircle(Offset(0, -2.24 * s), 0.05 * s, Paint()..color = accent);

  // Jetpack flame while airborne.
  if (altitude > 0.2) {
    final flicker = 0.7 + 0.3 * math.sin(time * 30);
    final flame = Path()
      ..moveTo(-0.12 * s, 0)
      ..lineTo(0.12 * s, 0)
      ..lineTo(0, 0.5 * s * flicker)
      ..close();
    canvas.drawPath(
      flame,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = const Color(0xCCFF9A3C),
    );
    canvas.drawCircle(
        Offset(0, 0.1 * s), 0.07 * s, Paint()..color = const Color(0xCCFFD35E));
  }
  canvas.restore();
}
