<h1 align="center">rainy_day</h1>

<p align="center">
  <strong>Hyper-realistic rain-on-glass effect for Flutter</strong>
</p>

<p align="center">
  <a href="https://pub.dev/packages/rainy_day"><img src="https://img.shields.io/pub/v/rainy_day.svg?logo=dart&label=pub.dev&color=blue" alt="pub.dev"></a>
  <a href="https://pub.dev/packages/rainy_day/score"><img src="https://img.shields.io/pub/points/rainy_day?logo=dart&color=teal" alt="pub points"></a>
  <a href="https://pub.dev/packages/rainy_day/score"><img src="https://img.shields.io/pub/popularity/rainy_day?logo=dart&color=blue" alt="popularity"></a>
  <a href="https://pub.dev/packages/rainy_day"><img src="https://img.shields.io/pub/likes/rainy_day?logo=dart&color=blue" alt="likes"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="MIT License"></a>
  <a href="https://github.com/azeemhassanch/flutter_rainyday"><img src="https://img.shields.io/github/stars/azeemhassanch/flutter_rainyday?style=social" alt="GitHub stars"></a>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/azeemhassanch/flutter_rainyday/main/screenshots/demo.png" width="280" alt="rainy_day screenshot" />
  &nbsp;&nbsp;
  <img src="https://raw.githubusercontent.com/azeemhassanch/flutter_rainyday/main/screenshots/rainy_day_demo.gif" width="280" alt="rainy_day demo" />
</p>

---

A faithful Flutter port of [RainyDay.js](https://github.com/maroslaw/rainyday.js) — falling drops with miniature reflections, collisions, trails, dynamic wind gusts, and accelerometer-driven parallax over a blurred background image.

## Features

- 🌧 **Realistic drop physics** — non-linear gravity with skip/slow cycles
- 🔍 **Miniature reflections** — each drop acts as a tiny lens into the background
- 💧 **Drop collisions & merging** — drops absorb each other on contact
- 〰️ **Trail drops** — falling drops leave small beads behind
- 🌬 **Wind gusts** — layered sine-wave wind with natural ramp up/down
- 🫧 **Per-drop wobble** — smooth coherent sway instead of random jitter
- 📱 **Accelerometer parallax** — background shifts with device tilt
- ⚙️ **Fully configurable** — blur, fps, gravity angle, collisions, wind, thresholds, presets

## Getting Started

### Installation

Add `rainy_day` to your `pubspec.yaml`:

```yaml
dependencies:
  rainy_day: ^1.0.0
```

Then run:

```bash
flutter pub get
```

### Import

```dart
import 'package:rainy_day/rainy_day.dart';
```

## Usage

Drop a `RainWidget` anywhere in your widget tree:

```dart
RainWidget(
  backgroundAsset: 'assets/images/background.jpg',
  blur: 10,
  fps: 60,
  enableCollisions: true,
  gravityThreshold: 3,
  windIntensity: 1.5,
  rainPresets: [
    RainPreset(3, 3, 0.88),
    RainPreset(5, 5, 0.90),
    RainPreset(6, 2, 1.00),
  ],
)
```

> **Note:** Make sure your background image is declared in your app's `pubspec.yaml` under `flutter > assets`.

## Configuration

| Parameter | Default | Description |
|:---|:---|:---|
| `backgroundAsset` | *required* | Asset path for the background image |
| `blur` | `10.0` | Gaussian blur sigma for the glass layer |
| `fps` | `60` | Physics updates per second |
| `enableCollisions` | `true` | Whether drops merge on contact |
| `gravityThreshold` | `3.0` | Drops with radius ≤ this become static beads |
| `gravityAngle` | `π/2` | Gravity direction in radians (π/2 = straight down) |
| `gravityAngleVariance` | `0.0` | Per-drop wobble amplitude (`0.02` = subtle sway) |
| `windIntensity` | `0.0` | Sideways wind force (`1.5` = breeze, `3+` = storm) |
| `enableParallax` | `true` | Accelerometer-driven background parallax |
| `rainPresets` | 3 presets | Drop size ranges and spawn probabilities |
| `rainInterval` | `100ms` | How often new drops are considered |
| `initialBeadCount` | `600` | Static wet-glass beads seeded at startup |
| `onControllerReady` | `null` | Callback to access the controller directly |

## Rain Presets

Each `RainPreset(minRadius, radiusVariance, probabilityOrCount)` defines a drop type:

- **Probability mode** (value ≤ 1): `RainPreset(3, 3, 0.88)` — 88% chance per interval
- **Count mode** (value > 1): `RainPreset(1, 2, 500)` — spawns 500 drops (for initial burst)

## Advanced: Controller Access

Access the controller to dynamically adjust rain intensity at runtime:

```dart
RainWidget(
  backgroundAsset: 'assets/images/background.jpg',
  onControllerReady: (controller) {
    // Adjust speed dynamically
    controller.speedMultiplier = 2.0;
    // Increase spawn rate for heavy rain
    controller.spawnMultiplier = 3;
  },
)
```

## Platforms

| Platform | Status |
|:---|:---|
| Android | ✅ Supported |
| iOS | ✅ Supported |

## Contributing

**Contributions are welcome and greatly appreciated!** 🎉

Whether it's a bug fix, new feature, documentation improvement, or performance optimization — we'd love to see your pull request.

1. Fork the repo
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please open an [issue](https://github.com/azeemhassanch/flutter_rainyday/issues) first to discuss major changes.

## Show Your Support

If you find this package useful, please consider:

- ⭐ **Star this repository** on [GitHub](https://github.com/azeemhassanch/flutter_rainyday) — it helps others discover the project!
- 👍 **Like this package** on [pub.dev](https://pub.dev/packages/rainy_day) — it motivates us to keep improving!
- 📢 **Share it** with fellow Flutter developers

Every star and like means a lot — thank you! 🙏

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/azeemhassanch">Azeem Hassan</a>
</p>
