import 'dart:async';

import 'package:flutter/widgets.dart';

import 'motion.dart';

/// Fades and slides its child in once, after an optional delay.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.index = 0,
    this.duration = Motion.medium,
    this.offset = const Offset(0, 16),
  });

  final Widget child;
  final Duration delay;

  /// Position in a list: each step adds [Motion.stagger] to [delay].
  final int index;
  final Duration duration;

  /// Starting offset in logical pixels.
  final Offset offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _t = CurvedAnimation(parent: _controller, curve: Motion.enter);
  Timer? _timer;

  Duration get _delay => widget.delay + Motion.stagger * widget.index;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted || _timer != null) return;
    if (Motion.of(context, widget.duration) == Duration.zero) {
      _controller.value = 1;
    } else if (_delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(_delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(offset: widget.offset * (1 - _t.value), child: child),
      ),
    );
  }
}
