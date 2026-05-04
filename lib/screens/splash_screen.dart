import 'package:flutter/material.dart';
import '../core/theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _scale = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fade  = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 1.0)));

    _ctrl.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 1200), widget.onDone);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0A3A), Color(0xFF3D1C00)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sparkles
                  FadeTransition(
                    opacity: _fade,
                    child: const Text('✦  ✦  ✦  ✦  ✦',
                        style: TextStyle(color: AppColors.accent, fontSize: 14, letterSpacing: 4)),
                  ),
                  const SizedBox(height: 24),
                  // Egg animation
                  ScaleTransition(
                    scale: _scale,
                    child: const Text('🐣', style: TextStyle(fontSize: 80)),
                  ),
                  const SizedBox(height: 32),
                  // Title
                  FadeTransition(
                    opacity: _fade,
                    child: const Text('달리몬',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        )),
                  ),
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: _fade,
                    child: const Text('DALLIMON  ·  v5.0',
                        style: TextStyle(color: AppColors.textSub, fontSize: 13, letterSpacing: 3)),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _fade,
                    child: const Text(
                      '걷기로 키우고\nNFC로 함께 싸우는\n세대 공감 산책 RPG',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSub, fontSize: 15, height: 1.8),
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Loading dots
                  FadeTransition(
                    opacity: _fade,
                    child: const _LoadingDots(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final idx = (_ctrl.value * 3).floor();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => Container(
            width: 7, height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == idx ? AppColors.primary : AppColors.textHint,
            ),
          )),
        );
      },
    );
  }
}
