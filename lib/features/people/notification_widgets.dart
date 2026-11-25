import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/notifications.dart';
import '../../app/providers.dart';
import '../../app/shell.dart';
import '../../app/social_providers.dart';
import '../../app/theme.dart';
import '../../domain/social/push.dart';
import '../../shared/animations/motion.dart';
import '../../shared/widgets/app_card.dart';
import 'bill_sheet.dart';
import 'inbox_screen.dart';
import 'people_widgets.dart';

/// Offers notifications on the People tab, once: until you turn them on or
/// say not now. Folds away when answered.
class NotificationsOffer extends ConsumerWidget {
  const NotificationsOffer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final show = ref.watch(notificationsProvider.select((s) => s.canOffer));
    final notifier = ref.read(notificationsProvider.notifier);
    return AnimatedSize(
      duration: Motion.of(context, Motion.medium),
      curve: Motion.enter,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: Motion.of(context, Motion.medium),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.97, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        child: !show
            ? const SizedBox(key: ValueKey('none'), width: double.infinity)
            : Padding(
                key: const ValueKey('offer'),
                padding: const EdgeInsets.only(top: 12),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Bell(color: c.lived),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Know when people reach out',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Get a notification when someone sends you a request, '
                                  'accepts yours, or adds you to a bill.',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: notifier.notNow, child: const Text('Not now')),
                          const SizedBox(width: 6),
                          FilledButton(
                            style: compactButton,
                            onPressed: notifier.turnOn,
                            child: const Text('Turn on'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// A bell that rings once when it appears.
class _Bell extends StatefulWidget {
  const _Bell({required this.color});

  final Color color;

  @override
  State<_Bell> createState() => _BellState();
}

class _BellState extends State<_Bell> with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.of(context, Motion.slow) != Duration.zero && !_ring.isAnimating) {
      unawaited(_ring.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ring,
    builder: (context, child) {
      // A swing that dies down: 0.25 rad, then smaller each way.
      final t = _ring.value;
      final angle = 0.25 * (1 - t) * _wave(t * 4);
      return Transform.rotate(angle: angle, alignment: Alignment.topCenter, child: child);
    },
    child: Icon(Icons.notifications_active_outlined, color: widget.color),
  );

  static double _wave(double x) {
    final f = x - x.floorToDouble();
    final up = (x.floor()).isEven;
    final tri = f < 0.5 ? f * 2 : 2 - f * 2; // 0..1..0
    return up ? tri : -tri;
  }
}

/// The notifications switch in Settings.
class NotificationsTile extends ConsumerWidget {
  const NotificationsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final state = ref.watch(notificationsProvider);
    if (!state.available) return const SizedBox.shrink();
    final notifier = ref.read(notificationsProvider.notifier);
    return SwitchListTile(
      secondary: Icon(Icons.notifications_none_rounded, color: c.ink2),
      title: const Text('Notifications'),
      subtitle: Text(
        state.blocked
            ? 'Turned off for Three Bucks in your phone’s Settings'
            : 'Requests and bills people add you to',
      ),
      value: state.on,
      onChanged: state.blocked ? null : (on) => on ? notifier.turnOn() : notifier.turnOff(),
    );
  }
}

/// Shows notifications that arrive while the app is open, opens the right
/// place when one is tapped, and notices permission changes made in the
/// phone's Settings. Wraps the main app, below the navigator.
class PushListener extends ConsumerStatefulWidget {
  const PushListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushListener> createState() => _PushListenerState();
}

class _PushListenerState extends ConsumerState<PushListener> {
  final _subs = <StreamSubscription<PushMessage>>[];
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(ref.read(notificationsProvider.notifier).refresh()),
    );
    final push = ref.read(pushServiceProvider);
    if (push == null) return;
    _subs
      ..add(push.received.listen(_show))
      ..add(push.opened.listen(_open));
    unawaited(
      push.launchMessage().then((m) {
        if (m != null) WidgetsBinding.instance.addPostFrameCallback((_) => _open(m));
      }),
    );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _lifecycle.dispose();
    super.dispose();
  }

  void _show(PushMessage m) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.title.isNotEmpty)
              Text(m.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (m.body.isNotEmpty) Text(m.body),
          ],
        ),
        action: SnackBarAction(label: 'View', onPressed: () => _open(m)),
      ),
    );
  }

  /// Requests and new bills open the inbox (or the bill itself, once it has
  /// arrived); an accepted request opens People.
  void _open(PushMessage m) {
    if (!mounted) return;
    ref.read(shellTabProvider.notifier).select(peopleTabIndex);
    final navigator = Navigator.of(context)..popUntil((r) => r.isFirst);
    switch (m.topic) {
      case PushTopic.accepted:
        break;
      case PushTopic.newBill when ref.read(billMapProvider).containsKey(m.id):
        unawaited(showBillSheet(context, m.id!));
      case PushTopic.request || PushTopic.newBill:
        unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => const InboxScreen())));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
