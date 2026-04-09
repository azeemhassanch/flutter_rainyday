import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rainy_day/rainy_day.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const RainApp());
}

class RainApp extends StatelessWidget {
  const RainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const Scaffold(
        body: RainWidget(
          backgroundAsset: 'assets/images/background.jpg',
          blur: 10,
          fps: 60,
          gravityThreshold: 3,
          gravityAngle: math.pi / 2,
          gravityAngleVariance: 0,
          windIntensity: 0,
          enableCollisions: true,
          rainPresets: [
            RainPreset(3, 3, 0.88),
            RainPreset(5, 5, 0.90),
            RainPreset(6, 2, 1.00),
          ],
          rainInterval: Duration(milliseconds: 100),
          initialBeadCount: 2500,
          initialBeadMinRadius: 1.0,
          initialBeadRadiusVariance: 2.0,
        ),
      ),
    );
  }
}
