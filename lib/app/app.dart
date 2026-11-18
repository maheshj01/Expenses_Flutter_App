import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/onboarding/onboarding_flow.dart';
import '../shared/animations/motion.dart';
import '../shared/animations/splash_reveal.dart';
import 'providers.dart';
import 'shell.dart';
import 'theme.dart';

class ThreeBucksApp extends StatelessWidget {
  const ThreeBucksApp({super.key, this.revealFromSplash = false});

  /// Animates out of the native launch screen. Only on a real launch (not in
  /// tests), where the native splash was just on screen.
  final bool revealFromSplash;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Three Bucks',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      builder: revealFromSplash ? (context, child) => SplashReveal(child: child!) : null,
      home: const _Root(),
    );
  }
}

/// Shows onboarding until it is done, then cross-fades into the app.
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(settingsProvider.select((s) => s.onboarded));
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.slow),
      switchInCurve: Motion.enter,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: onboarded
          ? const AppShell(key: ValueKey('app'))
          : const OnboardingFlow(key: ValueKey('onboarding')),
    );
  }
}
