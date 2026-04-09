import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'rainyday.dart';

/// Extra pixels on every side so a parallax shift never reveals an empty edge.
const double _kParallaxPad = 24.0;

/// [CustomPainter] that renders the full rain-on-glass scene:
///
/// 1. Blurred background with parallax
/// 2. Dark overlay for atmosphere
/// 3. All rain drops (static beads + falling physics drops)
class GlassPainter extends CustomPainter {
  final ui.Image background;
  final ui.Image? reflectionImage;
  final RainyDayController controller;

  final ValueNotifier<Offset> parallaxNotifier;

  late final Paint _bgPaint = Paint()
    ..filterQuality = FilterQuality.medium
    ..imageFilter = ui.ImageFilter.blur(
      sigmaX: controller.options.blurSigma,
      sigmaY: controller.options.blurSigma,
      tileMode: TileMode.clamp,
    );
  static final Paint _overlayPaint = Paint()..color = const Color(0x55080808);

  GlassPainter({
    required this.background,
    required this.controller,
    required this.parallaxNotifier,
    this.reflectionImage,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBlurredBackground(canvas, size, parallaxNotifier.value);
    _drawDarkOverlay(canvas, size);
    _drawDrops(canvas, size);
  }

  @override
  bool shouldRepaint(GlassPainter _) => false;

  void _drawBlurredBackground(Canvas canvas, Size size, Offset parallax) {
    final imgW = background.width.toDouble();
    final imgH = background.height.toDouble();

    final padW = size.width + 2 * _kParallaxPad;
    final padH = size.height + 2 * _kParallaxPad;

    final scale = math.max(padW / imgW, padH / imgH);

    final srcW = padW / scale;
    final srcH = padH / scale;
    final src = Rect.fromLTWH((imgW - srcW) / 2, (imgH - srcH) / 2, srcW, srcH);

    final ox = parallax.dx.clamp(-_kParallaxPad, _kParallaxPad);
    final oy = parallax.dy.clamp(-_kParallaxPad, _kParallaxPad);
    final dst = Rect.fromLTWH(
      -_kParallaxPad + ox,
      -_kParallaxPad + oy,
      padW,
      padH,
    );

    canvas.drawImageRect(background, src, dst, _bgPaint);
  }

  void _drawDarkOverlay(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      _overlayPaint,
    );
  }

  void _drawDrops(Canvas canvas, Size size) {
    final painter = RainyDayPainter(
      controller: controller,
      reflectionImage: reflectionImage,
    );
    painter.paint(canvas, size);
  }
}
