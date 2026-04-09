import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'rainyday.dart';
import 'rain_painter.dart';

/// A ready-to-use widget that renders a hyper-realistic rain-on-glass effect
/// over a blurred background image.
///
/// Simply provide a [backgroundAsset] path and the widget handles everything:
/// image loading, reflection computation, physics simulation, and rendering.
///
/// {@tool snippet}
/// ```dart
/// RainWidget(
///   backgroundAsset: 'assets/images/background.jpg',
///   blur: 10,
///   fps: 60,
///   enableCollisions: true,
///   gravityThreshold: 3,
///   windIntensity: 1.5,
///   rainPresets: [
///     RainPreset(3, 3, 0.88),
///     RainPreset(5, 5, 0.90),
///     RainPreset(6, 2, 1.00),
///   ],
/// )
/// ```
/// {@end-tool}
class RainWidget extends StatefulWidget {
  /// Asset path declared in pubspec.yaml (e.g. 'assets/images/background.jpg').
  final String backgroundAsset;

  /// Streamed drop presets – defines drop sizes and spawn probability.
  final List<RainPreset> rainPresets;

  /// How often a new streaming drop is considered (default 100 ms).
  final Duration rainInterval;

  /// How many static beads to seed on startup.
  final int initialBeadCount;

  /// Minimum radius for initial static beads.
  final double initialBeadMinRadius;

  /// Radius variance for initial static beads.
  final double initialBeadRadiusVariance;

  /// Physics updates per second.
  final int fps;

  /// Gaussian blur sigma applied to the background glass layer.
  final double blur;

  /// Whether drop collisions (merge) are enabled.
  final bool enableCollisions;

  /// Drops with radius ≤ this are static beads; above this they fall.
  final double gravityThreshold;

  /// Angle of gravity in radians (π/2 = straight down).
  final double gravityAngle;

  /// Per-drop wobble amplitude — smooth sine-based sway.
  /// 0 = straight lines, ~0.01–0.05 = subtle, ~0.1+ = wavy.
  final double gravityAngleVariance;

  /// Sideways wind force with natural gusts. 0 = calm, positive = right,
  /// negative = left. ~0.5–2 = breeze, 3+ = storm.
  final double windIntensity;

  /// Whether to enable accelerometer-driven background parallax.
  final bool enableParallax;

  /// Called once after the [RainyDayController] is created so the parent
  /// can hold a reference (e.g. to drive a speed slider).
  final ValueChanged<RainyDayController>? onControllerReady;

  const RainWidget({
    super.key,
    required this.backgroundAsset,
    this.rainPresets = const [
      RainPreset(3, 3, 0.88),
      RainPreset(5, 5, 0.90),
      RainPreset(6, 2, 1.00),
    ],
    this.rainInterval = const Duration(milliseconds: 100),
    this.initialBeadCount = 600,
    this.initialBeadMinRadius = 1.0,
    this.initialBeadRadiusVariance = 2.0,
    this.fps = 60,
    this.blur = 10.0,
    this.enableCollisions = true,
    this.gravityThreshold = 3.0,
    this.gravityAngle = math.pi / 2,
    this.gravityAngleVariance = 0.0,
    this.windIntensity = 0.0,
    this.enableParallax = true,
    this.onControllerReady,
  });

  @override
  State<RainWidget> createState() => _RainWidgetState();
}

class _RainWidgetState extends State<RainWidget>
    with SingleTickerProviderStateMixin {
  ui.Image? _bgImage;
  ui.Image? _reflImage;

  RainyDayController? _ctrl;
  Size _lastSize = Size.zero;

  final _repaint = _RepaintNotifier();

  final _parallax = ValueNotifier<Offset>(Offset.zero);
  StreamSubscription<AccelerometerEvent>? _accelSub;

  Ticker? _ticker;
  Duration _prevElapsed = Duration.zero;

  bool _loading = true;
  String? _error;
  bool _buildingRefl = false;

  @override
  void initState() {
    super.initState();
    _loadBackground();
    if (widget.enableParallax) {
      _initParallax();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _accelSub?.cancel();
    _parallax.dispose();
    _repaint.dispose();
    _bgImage?.dispose();
    _reflImage?.dispose();
    super.dispose();
  }

  void _initParallax() {
    try {
      _accelSub =
          accelerometerEventStream(
            samplingPeriod: SensorInterval.gameInterval,
          ).listen((event) {
            const maxShift = 20.0;
            final target = Offset(
              -(event.x / 9.8) * maxShift,
              (event.y / 9.8) * maxShift,
            );
            _parallax.value = Offset.lerp(_parallax.value, target, 0.08)!;
          });
    } catch (_) {
      // Sensor unavailable (simulator, web, desktop).
    }
  }

  Future<void> _loadBackground() async {
    try {
      final bytes = await rootBundle.load(widget.backgroundAsset);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _bgImage = frame.image;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _buildReflectionImage(Size size) async {
    if (_bgImage == null || _buildingRefl) return;
    _buildingRefl = true;

    final w = (size.width / 5).floorToDouble();
    final h = (size.height / 5).floorToDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      _bgImage!,
      Rect.fromLTWH(
        0,
        0,
        _bgImage!.width.toDouble(),
        _bgImage!.height.toDouble(),
      ),
      Rect.fromLTWH(0, 0, w, h),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(w.ceil(), h.ceil());
    picture.dispose();

    if (mounted) {
      setState(() {
        _reflImage?.dispose();
        _reflImage = image;
        _buildingRefl = false;
      });
    } else {
      image.dispose();
      _buildingRefl = false;
    }
  }

  void _ensureController(Size size) {
    if (_ctrl != null && _lastSize == size) return;
    _lastSize = size;

    final mappingSize = (200.0 * (size.shortestSide / 800.0)).clamp(
      60.0,
      300.0,
    );

    _ctrl = RainyDayController(
      options: RainyDayOptions(
        width: size.width,
        height: size.height,
        fps: widget.fps,
        blurSigma: widget.blur,
        gravityThreshold: widget.gravityThreshold,
        enableCollisions: widget.enableCollisions,
        gravityAngle: widget.gravityAngle,
        gravityAngleVariance: widget.gravityAngleVariance,
        windIntensity: widget.windIntensity,
        reflectionScaledownFactor: 5.0,
        reflectionDropMappingWidth: mappingSize,
        reflectionDropMappingHeight: mappingSize,
      ),
    );

    _ctrl!.rain(widget.rainPresets, interval: widget.rainInterval);

    widget.onControllerReady?.call(_ctrl!);

    final areaScale = (size.width * size.height) / (800.0 * 1400.0);
    final beadCount = (widget.initialBeadCount * areaScale).round().clamp(
      100,
      2000,
    );
    final rng = math.Random();
    for (int i = 0; i < beadCount; i++) {
      _ctrl!.putDrop(
        RainDrop(
          rainyDay: _ctrl!,
          x: rng.nextDouble() * size.width,
          y: rng.nextDouble() * size.height,
          minRadius: widget.initialBeadMinRadius,
          radiusVariance: widget.initialBeadRadiusVariance,
          random: rng,
        ),
      );
    }
  }

  void _startTicker() {
    if (_ticker != null) return;
    _ticker = createTicker((elapsed) {
      final delta = elapsed - _prevElapsed;
      _prevElapsed = elapsed;
      _ctrl?.step(delta);
      _repaint.notify();
    })..start();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: Color(0xFF020710),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF4A90D9),
            strokeWidth: 1.5,
          ),
        ),
      );
    }

    if (_error != null) {
      return ColoredBox(
        color: const Color(0xFF020710),
        child: Center(
          child: Text(
            'Could not load rain assets:\n$_error',
            style: const TextStyle(color: Color(0xFF4A90D9), fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        _ensureController(size);

        if (_reflImage == null && !_buildingRefl) {
          _buildReflectionImage(size);
        }

        _startTicker();

        return CustomPaint(
          size: size,
          painter: GlassPainter(
            background: _bgImage!,
            reflectionImage: _reflImage,
            controller: _ctrl!,
            parallaxNotifier: _parallax,
            repaint: _repaint,
          ),
        );
      },
    );
  }
}

class _RepaintNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
