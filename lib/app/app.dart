import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/account/deletion_pending_page.dart';
import '../features/account/restore_dialog.dart';
import '../features/onboarding/onboarding_flow.dart';
import '../shared/animations/motion.dart';
import '../shared/animations/splash_reveal.dart';
import 'account_flow.dart';
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
      home: const AppRoot(),
    );
  }
}

/// Shows onboarding until it is done, then cross-fades into the app. While
/// this phone's account is set to be deleted, the app gives way to the
/// choice of restoring it or letting it go.
class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(settingsProvider.select((s) => s.onboarded));
    final frozen = ref.watch(accountFlowProvider.select((s) => s.frozen));
    listenForRestoreConfirmation(ref, context);
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
      child: frozen
          ? const DeletionPendingPage(key: ValueKey('pending-deletion'))
          : onboarded
          ? const _SyncOnResume(key: ValueKey('app'), child: AppShell())
          : const OnboardingFlow(key: ValueKey('onboarding')),
    );
  }
}

/// Syncs when the app comes back to the foreground, if the last sync was a
/// while ago, so changes made on other devices show up.
class _SyncOnResume extends ConsumerStatefulWidget {
  const _SyncOnResume({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<_SyncOnResume> createState() => _SyncOnResumeState();
}

class _SyncOnResumeState extends ConsumerState<_SyncOnResume> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(ref.read(syncEngineProvider).syncIfStale()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
