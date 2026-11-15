import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'lunar_scene.dart' show paintAstronautSprite;

/// A point in the cabin. x = right, y = up, z = forward (heading 0 looks
/// along +z), the same convention as the Moon surface scene.
class _P {
  const _P(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
}

/// A point already moved into camera space.
class _C {
  const _C(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
}

/// One station panel in the cabin (a colony resource).
class ShipGauge {
  const ShipGauge(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;
}

/// Tiny perspective camera with near-plane clipping, so walls and floor stay
/// correct when the camera is close to them.
class _Cam {
  _Cam(this.eye, this.at, this.size) {
    var fx = at.x - eye.x, fy = at.y - eye.y, fz = at.z - eye.z;
    var fl = math.sqrt(fx * fx + fy * fy + fz * fz);
    if (fl < 0.0001) {
      fx = 0;
      fy = 0;
      fz = 1;
      fl = 1;
    }
    fx /= fl;
    fy /= fl;
    fz /= fl;
    // right = normalise(cross(worldUp, forward)) = (fz, 0, -fx)
    var rx = fz;
    var rz = -fx;
    final rl = math.sqrt(rx * rx + rz * rz);
    if (rl < 0.0001) {
      rx = 1;
      rz = 0;
    } else {
      rx /= rl;
      rz /= rl;
    }
    // up = cross(forward, right)
    final ux = fy * rz;
    final uy = fz * rx - fx * rz;
    final uz = -fy * rx;
    _f = [fx, fy, fz];
    _r = [rx, 0, rz];
    _u = [ux, uy, uz];
    focal = (size.height / 2) / math.tan(55 * math.pi / 360);
  }

  final _P eye;
  final _P at;
  final Size size;
  late final List<double> _f;
  late final List<double> _r;
  late final List<double> _u;
  late final double focal;

  _C toCam(_P p) {
    final dx = p.x - eye.x, dy = p.y - eye.y, dz = p.z - eye.z;
    return _C(
      dx * _r[0] + dy * _r[1] + dz * _r[2],
      dx * _u[0] + dy * _u[1] + dz * _u[2],
      dx * _f[0] + dy * _f[1] + dz * _f[2],
    );
  }

  double depth(_P p) => toCam(p).z;

  Offset _screen(_C c) => Offset(
        size.width / 2 + c.x * focal / c.z,
        size.height / 2 - c.y * focal / c.z,
      );

  /// Screen position of one point; null when it is behind the camera.
  Offset? project(_P p) {
    final c = toCam(p);
    if (c.z < 0.25) return null;
    return _screen(c);
  }

  /// A closed polygon (or an open polyline) clipped against the near plane.
  Path? poly(List<_P> pts, {bool closed = true}) {
    const near = 0.25;
    final cs = [for (final p in pts) toCam(p)];
    final out = <_C>[];
    final n = cs.length;
    for (var i = 0; i < n; i++) {
      final a = cs[i];
      if (!closed && i == n - 1) {
        if (a.z >= near) out.add(a);
        break;
      }
      final b = cs[(i + 1) % n];
      final aIn = a.z >= near;
      final bIn = b.z >= near;
      if (aIn) out.add(a);
      if (aIn != bIn) {
        final t = (near - a.z) / (b.z - a.z);
        out.add(_C(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, near));
      }
    }
    if (out.length < 2) return null;
    final path = Path();
    for (var i = 0; i < out.length; i++) {
      final o = _screen(out[i]);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    if (closed) path.close();
    return path;
  }
}

Color _rgb(int rgb, [double shade = 1]) {
  int ch(int v) => (v * shade).round().clamp(0, 255);
  return Color.fromARGB(255, ch((rgb >> 16) & 0xFF), ch((rgb >> 8) & 0xFF), ch(rgb & 0xFF));
}

/// Inside the spaceship, like the trainer: four station panels (oxygen,
/// power, water, food, shield), a mission board, a window to Earth and the green door.
class ShipInteriorPainter extends CustomPainter {
  ShipInteriorPainter({
    required this.pos,
    required this.camYaw,
    required this.moving,
    required this.time,
    required this.altitude,
    required this.gauges,
    required this.missions,
    required this.missionIndex,
    required this.timeLabel,
  });

  /// Astronaut position on the cabin floor (x, z).
  final Offset pos;
  final double camYaw;
  final bool moving;
  final double time;
  final double altitude;
  final List<ShipGauge> gauges;
  final List<String> missions;
  final int missionIndex;
  final String timeLabel;

  static const double halfX = 6;
  static const double halfZ = 5;
  static const double height = 4;

  // The same layout as the trainer, mirrored in x because this scene uses a
  // left-handed x-right/z-forward world.
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF05060F));

    final sx = math.sin(camYaw), cz = math.cos(camYaw);
    final cam = _Cam(
      _P((pos.dx - sx * 4).clamp(-5.6, 5.6), 2.4, (pos.dy - cz * 4).clamp(-4.6, 4.6)),
      _P(pos.dx + sx * 4, 1.3, pos.dy + cz * 4),
      size,
    );

    _fill(canvas, cam, [_P(-halfX, 0, -halfZ), _P(halfX, 0, -halfZ), _P(halfX, 0, halfZ), _P(-halfX, 0, halfZ)], _rgb(0x3A4056));
    _fill(canvas, cam, [_P(-halfX, height, -halfZ), _P(halfX, height, -halfZ), _P(halfX, height, halfZ), _P(-halfX, height, halfZ)], _rgb(0xE6E8F2));
    _fill(canvas, cam, [_P(-halfX, 0, -halfZ), _P(halfX, 0, -halfZ), _P(halfX, height, -halfZ), _P(-halfX, height, -halfZ)], _rgb(0xD6DAE6));
    _fill(canvas, cam, [_P(-halfX, 0, halfZ), _P(halfX, 0, halfZ), _P(halfX, height, halfZ), _P(-halfX, height, halfZ)], _rgb(0xC6CAD8));
    _fill(canvas, cam, [_P(-halfX, 0, -halfZ), _P(-halfX, 0, halfZ), _P(-halfX, height, halfZ), _P(-halfX, height, -halfZ)], _rgb(0xBEC3D6));
    _fill(canvas, cam, [_P(halfX, 0, -halfZ), _P(halfX, 0, halfZ), _P(halfX, height, halfZ), _P(halfX, height, -halfZ)], _rgb(0xBEC3D6));

    // Floor grid gives a feeling of depth.
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x33FFFFFF);
    for (var x = -halfX; x <= halfX; x += 2) {
      final p = cam.poly([_P(x, 0.01, -halfZ), _P(x, 0.01, halfZ)], closed: false);
      if (p != null) canvas.drawPath(p, grid);
    }
    for (var z = -halfZ; z <= halfZ; z += 2) {
      final p = cam.poly([_P(-halfX, 0.01, z), _P(halfX, 0.01, z)], closed: false);
      if (p != null) canvas.drawPath(p, grid);
    }

    // Ceiling light bars.
    for (final z in [-2.5, 2.5]) {
      _fill(canvas, cam, [_P(-5, height - 0.02, z - 0.15), _P(5, height - 0.02, z - 0.15), _P(5, height - 0.02, z + 0.15), _P(-5, height - 0.02, z + 0.15)], const Color(0xFFFFF2C0));
    }

    // Green door in the front wall (the way back out).
    _fill(canvas, cam, [_P(-0.9, 0, halfZ - 0.02), _P(0.9, 0, halfZ - 0.02), _P(0.9, 2.5, halfZ - 0.02), _P(-0.9, 2.5, halfZ - 0.02)], const Color(0xFF30C060), stroke: const Color(0xFF14602E));
    _fill(canvas, cam, [_P(-0.6, 0.25, halfZ - 0.03), _P(0.6, 0.25, halfZ - 0.03), _P(0.6, 2.2, halfZ - 0.03), _P(-0.6, 2.2, halfZ - 0.03)], const Color(0xFF58E08A));

    // Window with Earth on the right-hand wall.
    _window(canvas, cam);

    // Station panels. TL/TR/BL corners are listed as they read from inside
    // (back wall reads along -x, the x = +6 wall along -z, the x = -6 wall along +z).
    // Up to five panels: two on each side-wall position, two on the back wall.
    final slots = <List<_P>>[
      [_P(halfX - 0.07, 3.4, -0.9), _P(halfX - 0.07, 3.4, -3.2), _P(halfX - 0.07, 2.0, -0.9)],
      [_P(-halfX + 0.07, 3.4, -3.2), _P(-halfX + 0.07, 3.4, -0.9), _P(-halfX + 0.07, 2.0, -3.2)],
      [_P(4.1, 3.4, -halfZ + 0.07), _P(1.9, 3.4, -halfZ + 0.07), _P(4.1, 2.0, -halfZ + 0.07)],
      [_P(-2.1, 3.4, -halfZ + 0.07), _P(-4.3, 3.4, -halfZ + 0.07), _P(-2.1, 2.0, -halfZ + 0.07)],
      [_P(halfX - 0.07, 3.4, 3.3), _P(halfX - 0.07, 3.4, 1.0), _P(halfX - 0.07, 2.0, 3.3)],
    ];
    for (var i = 0; i < gauges.length && i < slots.length; i++) {
      final g = gauges[i];
      _panel(canvas, cam, slots[i][0], slots[i][1], slots[i][2], g.label.toUpperCase(), g.value, g.color);
    }
    _board(canvas, cam);

    // Props and the astronaut, drawn far to near.
    final items = <(double, VoidCallback)>[];
    void box(double x, double y, double z, double w, double h, double d, int rgb) {
      items.add((cam.depth(_P(x, y, z)), () => _box(canvas, cam, x, y, z, w, h, d, rgb)));
    }

    box(5.2, 1.3, -1.5, 1.1, 2.4, 1.1, 0x5EC8FF); // oxygen tanks
    box(5.2, 1.3, -2.8, 1.1, 2.4, 1.1, 0x5EC8FF);
    for (var i = 0; i < 2; i++) {
      for (var j = 0; j < 2; j++) {
        box(-5.2, 0.55 + i * 0.9, -1.5 - j * 1.3, 0.8, 0.8, 0.8, 0xFFD35E); // power cells
      }
    }
    box(3, 1, -4.2, 3, 1.4, 1.4, 0xFF8A3C); // fuel tank
    box(-3.2, 0.4, -4.2, 2.4, 0.5, 1.1, 0x2A6FD6); // crew benches
    box(-3.2, 1.4, -4.2, 2.4, 0.5, 1.1, 0x2A6FD6);
    box(0, 0.55, -2, 3, 1.1, 1, 0x2B3050); // control console
    box(0, 1.14, -2, 2.6, 0.06, 0.7, 0x2A90FF); // its glowing screen

    final feetP = _P(pos.dx, altitude, pos.dy);
    items.add((cam.depth(_P(pos.dx, 0, pos.dy)), () {
      final feet = cam.project(feetP);
      if (feet == null) return;
      final d = cam.depth(feetP);
      final s = cam.focal / d;
      final ground = cam.project(_P(pos.dx, 0, pos.dy));
      if (ground != null) {
        canvas.drawOval(
          Rect.fromCenter(center: ground, width: 1.1 * s, height: 0.4 * s),
          Paint()..color = Colors.black.withAlpha(90),
        );
      }
      paintAstronautSprite(canvas, feet, s, moving: moving, time: time, altitude: altitude);
    }));
    items.sort((a, b) => b.$1.compareTo(a.$1));
    for (final it in items) {
      it.$2();
    }
  }

  void _fill(Canvas canvas, _Cam cam, List<_P> pts, Color color, {Color? stroke}) {
    final path = cam.poly(pts);
    if (path == null) return;
    canvas.drawPath(path, Paint()..color = color);
    if (stroke != null) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = stroke,
      );
    }
  }

  /// A lit box: six faces drawn far to near with simple shading.
  void _box(Canvas canvas, _Cam cam, double cx, double cy, double cz, double w, double h, double d, int rgb) {
    final x0 = cx - w / 2, x1 = cx + w / 2;
    final y0 = cy - h / 2, y1 = cy + h / 2;
    final z0 = cz - d / 2, z1 = cz + d / 2;
    final faces = <(List<_P>, double)>[
      ([_P(x0, y1, z0), _P(x1, y1, z0), _P(x1, y1, z1), _P(x0, y1, z1)], 1.15), // top
      ([_P(x0, y0, z0), _P(x1, y0, z0), _P(x1, y1, z0), _P(x0, y1, z0)], 0.75), // -z
      ([_P(x0, y0, z1), _P(x1, y0, z1), _P(x1, y1, z1), _P(x0, y1, z1)], 0.9), // +z
      ([_P(x0, y0, z0), _P(x0, y0, z1), _P(x0, y1, z1), _P(x0, y1, z0)], 0.8), // -x
      ([_P(x1, y0, z0), _P(x1, y0, z1), _P(x1, y1, z1), _P(x1, y1, z0)], 0.95), // +x
    ];
    double faceDepth(List<_P> f) {
      var sx = 0.0, sy = 0.0, sz = 0.0;
      for (final p in f) {
        sx += p.x;
        sy += p.y;
        sz += p.z;
      }
      return cam.depth(_P(sx / f.length, sy / f.length, sz / f.length));
    }

    faces.sort((a, b) => faceDepth(b.$1).compareTo(faceDepth(a.$1)));
    for (final f in faces) {
      final path = cam.poly(f.$1);
      if (path == null) continue;
      canvas.drawPath(path, Paint()..color = _rgb(rgb, f.$2));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x55000000),
      );
    }
  }

  void _window(Canvas canvas, _Cam cam) {
    const x = -halfX + 0.03;
    final ring = <_P>[];
    final land = <_P>[];
    final cloud = <_P>[];
    for (var i = 0; i < 24; i++) {
      final a = i * 2 * math.pi / 24;
      ring.add(_P(x, 2.5 + math.sin(a) * 0.9, 1.8 + math.cos(a) * 0.9));
    }
    for (var i = 0; i < 12; i++) {
      final a = i * 2 * math.pi / 12;
      land.add(_P(x + 0.01, 2.7 + math.sin(a) * 0.28, 1.6 + math.cos(a) * 0.4));
      cloud.add(_P(x + 0.01, 2.2 + math.sin(a) * 0.12, 2.1 + math.cos(a) * 0.4));
    }
    _fill(canvas, cam, ring, const Color(0xFF1C5FC4), stroke: const Color(0xFF8A90A8));
    _fill(canvas, cam, land, const Color(0xCC3C9A52));
    _fill(canvas, cam, cloud, const Color(0x88FFFFFF));
  }

  void _text(Canvas canvas, String text, Offset at, double size, Color color, {double? maxWidth}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth ?? double.infinity);
    tp.paint(canvas, at);
  }

  /// Puts a flat piece of 2D drawing on a wall: [tl], [tr], [bl] are three
  /// corners, and the drawing area is [pw] x [ph] local units.
  bool _onWall(Canvas canvas, _Cam cam, _P tl, _P tr, _P bl, double pw, double ph) {
    final a = cam.project(tl), b = cam.project(tr), c = cam.project(bl);
    if (a == null || b == null || c == null) return false;
    final ex = b - a, ey = c - a;
    canvas.save();
    canvas.transform(Matrix4(
      ex.dx / pw, ex.dy / pw, 0, 0, //
      ey.dx / ph, ey.dy / ph, 0, 0, //
      0, 0, 1, 0, //
      a.dx, a.dy, 0, 1,
    ).storage);
    return true;
  }

  void _panel(Canvas canvas, _Cam cam, _P tl, _P tr, _P bl, String title, double v, Color col) {
    const pw = 300.0, ph = 190.0;
    if (!_onWall(canvas, cam, tl, tr, bl, pw, ph)) return;
    final low = v < 25;
    final rect = Rect.fromLTWH(0, 0, pw, ph);
    canvas.drawRect(rect, Paint()..color = const Color(0xF00A1026));
    canvas.drawRect(
      rect.deflate(3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = col,
    );
    _text(canvas, title, const Offset(16, 14), 22, const Color(0xFF97A2D0), maxWidth: pw - 32);
    _text(canvas, '${v.round()}%', const Offset(16, 46), 74, low ? const Color(0xFFFF7A7A) : Colors.white);
    canvas.drawRect(const Rect.fromLTWH(16, ph - 38, pw - 32, 16), Paint()..color = const Color(0x26FFFFFF));
    canvas.drawRect(
      Rect.fromLTWH(16, ph - 38, (pw - 32) * v.clamp(0, 100) / 100, 16),
      Paint()..color = low ? const Color(0xFFFF7A7A) : col,
    );
    canvas.restore();
  }

  void _board(Canvas canvas, _Cam cam) {
    const pw = 420.0, ph = 300.0;
    const z = -halfZ + 0.07;
    if (!_onWall(canvas, cam, const _P(1.7, 3.4, z), const _P(-1.7, 3.4, z), const _P(1.7, 1.0, z), pw, ph)) return;
    final rect = Rect.fromLTWH(0, 0, pw, ph);
    canvas.drawRect(rect, Paint()..color = const Color(0xF00A1026));
    canvas.drawRect(
      rect.deflate(3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = const Color(0xFFFFB347),
    );
    _text(canvas, 'MISSION BOARD   $timeLabel', const Offset(18, 16), 26, const Color(0xFFFFB347), maxWidth: pw - 36);
    for (var i = 0; i < missions.length; i++) {
      final done = i < missionIndex;
      final now = i == missionIndex;
      _text(
        canvas,
        '${done ? '✔' : now ? '▶' : '○'} ${missions[i]}',
        Offset(18, 78 + i * 52.0),
        21,
        done ? const Color(0xFF7BE0A0) : now ? Colors.white : const Color(0xFF97A2D0),
        maxWidth: pw - 36,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ShipInteriorPainter oldDelegate) => true;
}
