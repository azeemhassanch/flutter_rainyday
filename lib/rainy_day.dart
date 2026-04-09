/// Hyper-realistic rain-on-glass effect for Flutter.
///
/// Drop [RainWidget] into your widget tree with a background image asset
/// and it handles the full rain simulation — blurred glass, falling drops
/// with miniature reflections, collisions, trails, wind gusts, and parallax.
///
/// ```dart
/// import 'package:rainy_day/rainy_day.dart';
///
/// RainWidget(
///   backgroundAsset: 'assets/images/background.jpg',
///   blur: 10,
///   fps: 60,
///   enableCollisions: true,
///   windIntensity: 1.5,
///   rainPresets: [
///     RainPreset(3, 3, 0.88),
///     RainPreset(5, 5, 0.90),
///     RainPreset(6, 2, 1.00),
///   ],
/// )
/// ```
library;

export 'src/rainyday.dart'
    show
        RainyDayOptions,
        RainPreset,
        RainDrop,
        RainyDayController,
        RainyDayPainter;
export 'src/rain_painter.dart' show GlassPainter;
export 'src/rain_widget.dart' show RainWidget;
