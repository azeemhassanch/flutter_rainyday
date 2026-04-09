import 'package:flutter_test/flutter_test.dart';
import 'package:rainy_day/rainy_day.dart';

void main() {
  test('RainyDayOptions has correct defaults', () {
    const options = RainyDayOptions(width: 400, height: 800);
    expect(options.blurSigma, 10.0);
    expect(options.fps, 60);
    expect(options.enableCollisions, true);
    expect(options.gravityThreshold, 3.0);
    expect(options.windIntensity, 0.0);
  });

  test('RainPreset stores values', () {
    const preset = RainPreset(3, 5, 0.88);
    expect(preset.minRadius, 3);
    expect(preset.radiusVariance, 5);
    expect(preset.probabilityOrCount, 0.88);
  });

  test('RainyDayController spawns drops', () {
    final ctrl = RainyDayController(
      options: const RainyDayOptions(width: 400, height: 800),
    );
    ctrl.rain(const [RainPreset(3, 3, 0.88)]);

    // Step for 200ms — should spawn some drops
    ctrl.step(const Duration(milliseconds: 200));
    expect(ctrl.drops.length + ctrl.staticDrops.length, greaterThan(0));
  });
}
