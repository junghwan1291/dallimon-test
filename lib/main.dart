import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'state/game_notifier.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const ProviderScope(child: DallimonApp()));
}

class DallimonApp extends StatelessWidget {
  const DallimonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '달리몬',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      home: const _AppRouter(),
    );
  }
}

// ── Routing ───────────────────────────────────────────────
class _AppRouter extends ConsumerStatefulWidget {
  const _AppRouter();

  @override
  ConsumerState<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends ConsumerState<_AppRouter> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return SplashScreen(onDone: () => setState(() => _splashDone = true));
    }

    final gs = ref.watch(gameProvider);

    if (!gs.onboardingDone) {
      return const OnboardingScreen();
    }

    return const MainShell();
  }
}
