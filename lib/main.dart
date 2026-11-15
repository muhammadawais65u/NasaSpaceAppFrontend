import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screen.dart';
import 'services/game_controller.dart';
import 'widgets/ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The screens are designed wide, like the mock-ups. No effect in a browser.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const JuniorAstronautApp());
}

class JuniorAstronautApp extends StatefulWidget {
  const JuniorAstronautApp({super.key});

  @override
  State<JuniorAstronautApp> createState() => _JuniorAstronautAppState();
}

class _JuniorAstronautAppState extends State<JuniorAstronautApp> {
  final GameController _controller = GameController();

  @override
  void initState() {
    super.initState();
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameScope(
      controller: _controller,
      child: MaterialApp(
        title: 'Junior Astronaut - Moon Survival Adventure',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
              seedColor: GameColors.blue, brightness: Brightness.dark),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
