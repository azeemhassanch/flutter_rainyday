import 'dart:math' as math;
import 'dart:ui';

/// Configuration options for the rain simulation engine.
///
/// This mirrors the JS RainyDay constructor options.
///
/// ```dart
/// RainyDayOptions(
///   width: 400,
///   height: 800,
///   blurSigma: 10,
///   fps: 60,
///   enableCollisions: true,
///   gravityThreshold: 3,
///   gravityAngle: math.pi / 2,
///   gravityAngleVariance: 0.02,
///   windIntensity: 1.5,
/// )
/// ```
class RainyDayOptions {
  final double blurSigma;
  final int fps;
  final bool enableCollisions;
  final double gravityThreshold;
  final double gravityAngle;
  final double gravityAngleVariance;

  /// Sideways wind force. 0 = calm, positive = rightward, negative = leftward.
  /// Values around 0.5–2.0 give a noticeable breeze; 3+ is a storm.
  /// The force oscillates over time to simulate natural gusts.
  final double windIntensity;

  final double reflectionScaledownFactor;
  final double reflectionDropMappingWidth;
  final double reflectionDropMappingHeight;
  final double width;
  final double height;

  const RainyDayOptions({
    required this.width,
    required this.height,
    this.blurSigma = 10.0,
    this.fps = 60,
    this.enableCollisions = true,
    this.gravityThreshold = 3.0,
    this.gravityAngle = math.pi / 2,
    this.gravityAngleVariance = 0.0,
    this.windIntensity = 0.0,
    this.reflectionScaledownFactor = 5.0,
    this.reflectionDropMappingWidth = 200.0,
    this.reflectionDropMappingHeight = 200.0,
  });
}

/// Defines a rain drop preset – size range and spawn probability.
///
/// When [probabilityOrCount] ≤ 1 it is treated as a per-tick probability
/// (0.88 = 88 % chance). When > 1 it is a fixed count that spawns that many
/// drops every interval.
///
/// ```dart
/// const RainPreset(3, 3, 0.88) // min radius 3, variance 3, 88% probability
/// ```
class RainPreset {
  final double minRadius;
  final double radiusVariance;
  final double probabilityOrCount;

  const RainPreset(
    this.minRadius,
    this.radiusVariance,
    this.probabilityOrCount,
  );
}

class RainDrop {
  double x;
  double y;
  double r;

  final RainyDayController rainyDay;

  double? ySpeed;
  double? xSpeed;
  double? trailY;
  double? seed;

  bool skipping = false;
  bool slowing = false;
  bool collided = false;
  bool terminate = false;

  RainDrop? colliding;

  String? gid;
  int? gmx;
  int? gmy;

  RainDrop({
    required this.rainyDay,
    required this.x,
    required this.y,
    required double minRadius,
    required double radiusVariance,
    math.Random? random,
  }) : r = ((random ?? math.Random()).nextDouble() * radiusVariance + minRadius)
           .ceilToDouble();

  bool animate(double dt) {
    if (terminate) return false;

    final stopped = rainyDay.gravity(this, dt);

    if (!stopped && rainyDay.trail != null) {
      rainyDay.trail!(this);
    }

    if (rainyDay.options.enableCollisions && rainyDay.matrix != null) {
      final list = rainyDay.matrix!.update(this, stopped);
      if (list != null && list.isNotEmpty) {
        rainyDay.collision(this, list);
      }
    }

    return !stopped;
  }

  bool clear([bool force = false]) {
    if (force) {
      terminate = true;
      return true;
    }

    return y - r > rainyDay.options.height ||
        x - r > rainyDay.options.width ||
        x + r < 0;
  }

  Path buildPath() {
    final path = Path();
    final originalR = r;
    r = (0.95 * r).floorToDouble();

    if (r < 3) {
      path.addOval(Rect.fromCircle(center: Offset(x, y), radius: r));
    } else if (colliding != null || (ySpeed ?? 0) > 2) {
      if (colliding != null) {
        x += (colliding!.x - x) * 0.3;
        colliding = null;
      }

      final c = 1 + 0.1 * (ySpeed ?? 0);
      path.moveTo(x - r / c, y);
      path.cubicTo(x - r, y - 2 * r, x + r, y - 2 * r, x + r / c, y);
      path.cubicTo(x + r, y + c * r, x - r, y + c * r, x - r / c, y);
      path.close();
    } else {
      final rr = 0.9 * r;
      path.moveTo(x - rr * 0.85, y);
      path.cubicTo(
        x - rr * 0.5,
        y - rr * 1.6,
        x + rr * 0.5,
        y - rr * 1.6,
        x + rr * 0.85,
        y,
      );
      path.cubicTo(
        x + rr,
        y + rr * 1.1,
        x - rr,
        y + rr * 1.1,
        x - rr * 0.85,
        y,
      );
      path.close();
    }

    r = originalR;
    return path;
  }
}

class DropItem {
  RainDrop? drop;
  DropItem? next;

  DropItem(this.drop);

  void add(RainDrop drop) {
    DropItem current = this;
    while (current.next != null) {
      current = current.next!;
    }
    current.next = DropItem(drop);
  }

  void remove(RainDrop drop) {
    DropItem current = this;
    DropItem? previous;

    while (current.next != null) {
      previous = current;
      current = current.next!;
      if (current.drop?.gid == drop.gid) {
        previous.next = current.next;
        return;
      }
    }
  }
}

class CollisionMatrix {
  final int resolution;
  final int xc;
  final int yc;
  final List<List<DropItem>> matrix;

  CollisionMatrix(this.xc, this.yc, this.resolution)
    : matrix = List.generate(
        xc + 6,
        (_) => List.generate(yc + 6, (_) => DropItem(null)),
      );

  final List<RainDrop> _scratch = <RainDrop>[];

  List<RainDrop>? update(RainDrop drop, bool stopped) {
    if (drop.gid != null) {
      if (!_hasCell(drop.gmx, drop.gmy)) return null;
      matrix[drop.gmx!][drop.gmy!].remove(drop);
      if (stopped) return null;

      drop.gmx = (drop.x / resolution).floor();
      drop.gmy = (drop.y / resolution).floor();
      if (!_hasCell(drop.gmx, drop.gmy)) return null;

      matrix[drop.gmx!][drop.gmy!].add(drop);
      _collectNearby(drop);
      return _scratch.isNotEmpty ? _scratch : null;
    }

    drop.gid = _randomId();
    drop.gmx = (drop.x / resolution).floor();
    drop.gmy = (drop.y / resolution).floor();
    if (!_hasCell(drop.gmx, drop.gmy)) return null;

    matrix[drop.gmx!][drop.gmy!].add(drop);
    return null;
  }

  void _collectNearby(RainDrop drop) {
    _scratch.clear();
    _addAll(drop.gmx! - 1, drop.gmy! + 1);
    _addAll(drop.gmx!, drop.gmy! + 1);
    _addAll(drop.gmx! + 1, drop.gmy! + 1);
  }

  void _addAll(int x, int y) {
    if (x >= 0 && y >= 0 && x < matrix.length && y < matrix[x].length) {
      DropItem current = matrix[x][y];
      while (current.next != null) {
        current = current.next!;
        if (current.drop != null) _scratch.add(current.drop!);
      }
    }
  }

  void remove(RainDrop drop) {
    if (_hasCell(drop.gmx, drop.gmy)) {
      matrix[drop.gmx!][drop.gmy!].remove(drop);
    }
  }

  bool _hasCell(int? x, int? y) {
    if (x == null || y == null) return false;
    return x >= 0 && y >= 0 && x < matrix.length && y < matrix[x].length;
  }

  static int _idCounter = 0;
  String _randomId() => 'drop_${++_idCounter}';
}

typedef TrailBehavior = void Function(RainDrop drop);
typedef GravityBehavior = bool Function(RainDrop drop, double dt);
typedef CollisionBehavior = void Function(RainDrop drop, List<RainDrop> nearby);

/// Core rain simulation controller.
///
/// Manages drop spawning, physics (gravity, trails, collisions), and the
/// per-frame update loop. Typically created and driven by [RainWidget], but
/// can also be used standalone with a custom ticker.
class RainyDayController {
  final RainyDayOptions options;
  final math.Random _random;

  List<RainDrop> drops = <RainDrop>[];

  List<RainDrop> staticDrops = <RainDrop>[];
  static const int _kMaxStaticDrops = 2000;
  int _staticWriteIdx = 0;

  List<RainPreset> presets = <RainPreset>[];
  CollisionMatrix? matrix;

  TrailBehavior? trail;
  late GravityBehavior gravity;
  late CollisionBehavior collision;

  double privateGravityForceFactorY = 0;
  double privateGravityForceFactorX = 0;

  /// Multiplier applied to gravity forces. 1.0 = normal speed.
  double speedMultiplier = 1.0;

  /// Accumulated simulation time in seconds — drives wind gust oscillation.
  double _elapsed = 0.0;

  static const int _kMaxPhysicsDrops = 500;

  Duration spawnInterval = const Duration(milliseconds: 50);
  Duration _spawnAccumulator = Duration.zero;

  /// How many times _spawnDrops() runs per tick. 1 = normal, 4 = heavy.
  int spawnMultiplier = 1;

  RainyDayController({required this.options, math.Random? random})
    : _random = random ?? math.Random() {
    trail = trailDrops;
    gravity = gravityNonLinear;
    collision = collisionSimple;
  }

  void rain(
    List<RainPreset> nextPresets, {
    Duration interval = const Duration(milliseconds: 50),
  }) {
    presets = nextPresets;
    spawnInterval = interval;

    privateGravityForceFactorY = (0.001 * options.fps) / 25;
    privateGravityForceFactorX =
        ((math.pi / 2 - options.gravityAngle) * (0.001 * options.fps)) / 50;

    if (options.enableCollisions) {
      int maxDrop = 0;
      for (final preset in presets) {
        final candidate = (preset.minRadius + preset.radiusVariance).floor();
        if (candidate > maxDrop) maxDrop = candidate;
      }

      if (maxDrop > 0) {
        final x = (options.width / maxDrop).ceil();
        final y = (options.height / maxDrop).ceil();
        matrix = CollisionMatrix(x, y, maxDrop);
      }
    }
  }

  void step(Duration elapsed) {
    _spawnAccumulator += elapsed;

    final maxAccum = spawnInterval * 2;
    if (_spawnAccumulator > maxAccum) {
      _spawnAccumulator = maxAccum;
    }

    while (_spawnAccumulator >= spawnInterval) {
      _spawnAccumulator -= spawnInterval;
      for (int m = 0; m < spawnMultiplier; m++) {
        _spawnDrops();
      }
    }

    _elapsed += elapsed.inMilliseconds / 1000.0;

    final dt = elapsed.inMilliseconds / (1000 / options.fps);

    int writeIdx = 0;
    for (int i = 0; i < drops.length; i++) {
      if (drops[i].animate(dt)) {
        drops[writeIdx++] = drops[i];
      } else {
        if (options.enableCollisions && matrix != null) {
          matrix!.remove(drops[i]);
        }
      }
    }
    drops.length = writeIdx;

    if (staticDrops.length < _kMaxStaticDrops) {
      final toAdd = math.min(3, _kMaxStaticDrops - staticDrops.length);
      for (int i = 0; i < toAdd; i++) {
        putDrop(
          RainDrop(
            rainyDay: this,
            x: _random.nextDouble() * options.width,
            y: _random.nextDouble() * options.height,
            minRadius: 1.0,
            radiusVariance: 2.0,
            random: _random,
          ),
        );
      }
    }
  }

  void _spawnDrops() {
    RainPreset? probabilityHit;
    for (final preset in presets) {
      if (preset.probabilityOrCount > 1) {
        for (int i = 0; i < preset.probabilityOrCount.floor(); i++) {
          putDrop(_newDrop(preset));
        }
      } else if (probabilityHit == null &&
          _random.nextDouble() < preset.probabilityOrCount) {
        probabilityHit = preset;
      }
    }
    if (probabilityHit != null) {
      putDrop(_newDrop(probabilityHit));
    }
  }

  RainDrop _newDrop(RainPreset preset) {
    return RainDrop(
      rainyDay: this,
      x: _random.nextDouble() * options.width,
      y: _random.nextDouble() * options.height,
      minRadius: preset.minRadius,
      radiusVariance: preset.radiusVariance,
      random: _random,
    );
  }

  void putDrop(RainDrop drop) {
    if (drop.r > options.gravityThreshold) {
      if (drops.length >= _kMaxPhysicsDrops) return;
      if (options.enableCollisions && matrix != null) {
        matrix!.update(drop, false);
      }
      drops.add(drop);
    } else {
      if (staticDrops.length < _kMaxStaticDrops) {
        staticDrops.add(drop);
      } else {
        staticDrops[_staticWriteIdx] = drop;
      }
      _staticWriteIdx = (_staticWriteIdx + 1) % _kMaxStaticDrops;
    }
  }

  bool clearDrop(RainDrop drop, [bool force = false]) {
    return drop.clear(force);
  }

  void trailDrops(RainDrop drop) {
    if (drop.trailY == null ||
        drop.y - drop.trailY! >= 100 * _random.nextDouble() * drop.r) {
      drop.trailY = drop.y;
      putDrop(
        RainDrop(
          rainyDay: this,
          x: (drop.x + (2 * _random.nextDouble() - 1) * _random.nextDouble())
              .floorToDouble(),
          y: drop.y - drop.r - 5,
          minRadius: (drop.r / 5).ceilToDouble(),
          radiusVariance: 0,
          random: _random,
        ),
      );
    }
  }

  bool gravityNonLinear(RainDrop drop, double dt) {
    if (clearDrop(drop)) return true;

    final sm = speedMultiplier;

    if (drop.collided) {
      drop.collided = false;
      drop.seed = (drop.r * _random.nextDouble() * options.fps).floorToDouble();
      drop.skipping = false;
      drop.slowing = false;
    } else if (drop.seed == null || drop.seed! < 0) {
      drop.seed = (drop.r * _random.nextDouble() * options.fps).floorToDouble();
      drop.skipping = !drop.skipping;
      drop.slowing = true;
    }

    drop.seed = (drop.seed ?? 0) - 1;

    if (drop.ySpeed != null) {
      if (drop.slowing) {
        drop.ySpeed = drop.ySpeed! / 1.1;
        drop.xSpeed = (drop.xSpeed ?? 0) / 1.1;
        if (drop.ySpeed! < privateGravityForceFactorY) {
          drop.slowing = false;
        }
      } else if (drop.skipping) {
        drop.ySpeed = privateGravityForceFactorY * sm;
        drop.xSpeed = privateGravityForceFactorX * sm;
      } else {
        drop.ySpeed =
            drop.ySpeed! + privateGravityForceFactorY * drop.r.floor() * sm;
        drop.xSpeed =
            (drop.xSpeed ?? 0) +
            privateGravityForceFactorX * drop.r.floor() * sm;
      }
    } else {
      drop.ySpeed = privateGravityForceFactorY * sm;
      drop.xSpeed = privateGravityForceFactorX * sm;
    }

    // ── Wind gusts ─────────────────────────────────────────────────────────
    if (options.windIntensity != 0) {
      final t = _elapsed;
      final gust =
          math.sin(t * 0.4) * 0.5 +
          math.sin(t * 1.1) * 0.3 +
          math.sin(t * 2.7) * 0.2;
      drop.xSpeed =
          (drop.xSpeed ?? 0) +
          gust * options.windIntensity * 0.002 * options.fps;
    }

    // ── Per-drop coherent wobble ───────────────────────────────────────────
    if (options.gravityAngleVariance != 0) {
      final phase = (drop.seed ?? 0) * 0.37;
      final wobble = math.sin(drop.y * 0.03 + phase);
      drop.xSpeed =
          (drop.xSpeed ?? 0) +
          wobble * drop.ySpeed! * options.gravityAngleVariance;
    }

    drop.y += drop.ySpeed!.floorToDouble();
    drop.x += (drop.xSpeed ?? 0).floorToDouble();
    return false;
  }

  double positiveMin(double a, double b) {
    double c = 0;
    c = a < b ? (a <= 0 ? b : a) : (b <= 0 ? a : b);
    return c <= 0 ? 1 : c;
  }

  void collisionSimple(RainDrop drop, List<RainDrop> nearby) {
    RainDrop? collided;

    for (int i = 0; i < nearby.length; i++) {
      final other = nearby[i];
      final f = drop.r + other.r;
      final g = drop.x - other.x;
      final h = drop.y - other.y;

      if (g.abs() < f && h.abs() < f && (g * g + h * h) < f * f) {
        collided = other;
        break;
      }
    }

    if (collided != null) {
      final survivor = drop;
      final consumed = collided;

      survivor.r = 1.001 * (survivor.r > consumed.r ? survivor.r : consumed.r);

      clearDrop(survivor);
      clearDrop(consumed, true);
      matrix?.remove(consumed);
      survivor.colliding = consumed;
      survivor.collided = true;
    }
  }
}

/// Low-level drop painter used by [GlassPainter].
///
/// Renders each drop with a clipped miniature-reflection of the background
/// image and a specular highlight rim.
class RainyDayPainter {
  final RainyDayController controller;
  final Image? reflectionImage;

  static final Paint _reflPaint = Paint()..filterQuality = FilterQuality.medium;
  static final Paint _fallbackPaint = Paint()..color = const Color(0x30FFFFFF);
  static final Paint _specularPaint = Paint()..color = const Color(0x22FFFFFF);

  RainyDayPainter({required this.controller, this.reflectionImage});

  void paint(Canvas canvas, Size size) {
    for (final drop in controller.staticDrops) {
      _paintDrop(canvas, drop, isStatic: true);
    }
    for (final drop in controller.drops) {
      _paintDrop(canvas, drop, isStatic: false);
    }
  }

  void _paintDrop(Canvas canvas, RainDrop drop, {required bool isStatic}) {
    final path = drop.buildPath();
    canvas.save();
    canvas.clipPath(path);

    if (reflectionImage != null) {
      _drawMiniatureReflection(canvas, drop, reflectionImage!);
    } else {
      canvas.drawPath(path, _fallbackPaint);
    }

    if (!isStatic) {
      _drawSpecularRim(canvas, drop);
    }

    canvas.restore();
  }

  void _drawSpecularRim(Canvas canvas, RainDrop drop) {
    final r = drop.r;
    final hlRect = Rect.fromCenter(
      center: Offset(drop.x - r * 0.25, drop.y - r * 0.35),
      width: r * 0.55,
      height: r * 0.30,
    );
    _specularPaint.maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25);
    canvas.drawOval(hlRect, _specularPaint);
  }

  void _drawMiniatureReflection(Canvas canvas, RainDrop drop, Image image) {
    final b = math.max(
      (drop.x - controller.options.reflectionDropMappingWidth) /
          controller.options.reflectionScaledownFactor,
      0,
    );
    final c = math.max(
      (drop.y - controller.options.reflectionDropMappingHeight) /
          controller.options.reflectionScaledownFactor,
      0,
    );

    final d = controller.positiveMin(
      (2 * controller.options.reflectionDropMappingWidth) /
          controller.options.reflectionScaledownFactor,
      image.width.toDouble() - b,
    );
    final e = controller.positiveMin(
      (2 * controller.options.reflectionDropMappingHeight) /
          controller.options.reflectionScaledownFactor,
      image.height.toDouble() - c,
    );

    final f = math.max(drop.x - 1.1 * drop.r, 0);
    final g = math.max(drop.y - 1.1 * drop.r, 0);

    final src = Rect.fromLTWH(
      b.floorToDouble(),
      c.floorToDouble(),
      d.floorToDouble(),
      e.floorToDouble(),
    );
    final dst = Rect.fromLTWH(
      f.floorToDouble(),
      g.floorToDouble(),
      2 * drop.r,
      2 * drop.r,
    );

    canvas.drawImageRect(image, src, dst, _reflPaint);
  }
}
