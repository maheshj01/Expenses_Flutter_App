import 'package:flutter/widgets.dart';

import 'motion.dart';

/// Counts smoothly from the previous value to [cents] whenever it changes.
class AnimatedAmount extends StatelessWidget {
  const AnimatedAmount({
    super.key,
    required this.cents,
    required this.builder,
    this.duration = Motion.slow,
  });

  final int cents;
  final Duration duration;

  /// Builds the widget for an in-between value.
  final Widget Function(BuildContext context, int cents) builder;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: cents.toDouble()),
      duration: Motion.of(context, duration),
      curve: Motion.enter,
      builder: (context, value, _) => builder(context, value.round()),
    );
  }
}
