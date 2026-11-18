import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../shared/animations/motion.dart';

/// The app mark: three bars for Lived, Invested and Earned that rise in
/// one after another.
class ThreeBucksMark extends StatefulWidget {
  const ThreeBucksMark({super.key, this.size = 88});

  final double size;

  @override
  State<ThreeBucksMark> createState() => _ThreeBucksMarkState();
}

class _ThreeBucksMarkState extends State<ThreeBucksMark> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.of(context, Motion.slow) == Duration.zero) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && !_controller.isCompleted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = widget.size;
    final bars = [(0.55, c.lived), (0.85, c.invested), (0.7, c.earned)];
    return Container(
      width: s,
      height: s,
      padding: EdgeInsets.all(s * 0.18),
      decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(s * 0.28)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final (i, (height, color)) in bars.indexed)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = CurvedAnimation(
                  parent: _controller,
                  curve: Interval(i * 0.15, 0.55 + i * 0.15, curve: Curves.elasticOut),
                ).value;
                return Container(
                  width: s * 0.16,
                  height: (s * 0.64 * height * t).clamp(0, s),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(s * 0.05),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
