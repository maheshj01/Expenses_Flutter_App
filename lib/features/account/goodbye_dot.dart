import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The goodbye page's one dot: a filled dot is something kept, a hollow
/// ring nothing left.
///
/// It beats twice (the account, still going), then its fill drains inward
/// and leaves a ring. From there:
///  - [erased]: a stop. The ring stays empty and perfectly still, above
///    "Start over".
///  - otherwise: a pause. A faint light breathes inside the ring, like a
///    sleeping laptop's standby light, for as long as the page is open;
///    signing in within the grace period fills the dot again.
///
/// With reduced motion the dot shows its final state at once.
class GoodbyeDot extends StatefulWidget {
  const GoodbyeDot({super.key, required this.erased, this.color = Colors.white});

  final bool erased;
  final Color color;

  static const double size = 22;

  @override
  State<GoodbyeDot> createState() => _GoodbyeDotState();
}

class _GoodbyeDotState extends State<GoodbyeDot> with TickerProviderStateMixin {
  /// Hold, two beats, drain.
  late final AnimationController _stop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  /// The paused dot's standby light: one breath every 2.4 s.
  late final AnimationController _standby = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _stop.value = 1;
      // A still, dim light: paused, without the motion.
      if (!widget.erased) _standby.value = 0.6;
      return;
    }
    _stop.forward().whenComplete(() {
      if (mounted && !widget.erased) _standby.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _stop.dispose();
    _standby.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: GoodbyeDot.size,
        // The beats swell past this box; nothing clips them.
        child: CustomPaint(
          painter: _GoodbyeDotPainter(stop: _stop, standby: _standby, color: widget.color),
        ),
      ),
    );
  }
}

class _GoodbyeDotPainter extends CustomPainter {
  _GoodbyeDotPainter({required this.stop, required this.standby, required this.color})
    : super(repaint: Listenable.merge([stop, standby]));

  final Animation<double> stop;
  final Animation<double> standby;
  final Color color;

  static const double _stroke = 2;

  /// Where each part of [stop] falls, as shares of its 2 s: a beat to let
  /// the page fade in, a strong beat and a softer one close behind it
  /// (lub-dub), a rest, then the drain.
  static const _firstBeat = (0.15, 0.33, 0.16);
  static const _secondBeat = (0.36, 0.52, 0.09);
  static const _drainStart = 0.62;
  static const _drainEnd = 0.97;

  static double _share(double t, double from, double to) =>
      ((t - from) / (to - from)).clamp(0.0, 1.0);

  /// Extra scale from one beat: a quick swell and a slower settle.
  static double _beat(double t, (double, double, double) beat) {
    final (from, to, strength) = beat;
    final u = _share(t, from, to);
    if (u == 0 || u == 1) return 0;
    return strength * math.pow(math.sin(math.pi * u), 2) * (1 - 0.35 * u);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = stop.value;
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final scale = 1 + _beat(t, _firstBeat) + _beat(t, _secondBeat);
    final drained = Curves.easeInCubic.transform(_share(t, _drainStart, _drainEnd));

    // The fill, shrinking toward the centre as it empties.
    final fillRadius = r * scale * (1 - drained);
    if (fillRadius > 0.2) {
      canvas.drawCircle(center, fillRadius, Paint()..color = color);
    }

    // The ring the fill leaves behind, coming up as it goes.
    final ringAlpha = math.min(1.0, drained * 1.8);
    if (ringAlpha > 0) {
      canvas.drawCircle(
        center,
        r - _stroke / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..color = color.withValues(alpha: ringAlpha),
      );
    }

    // Paused only: the standby light inside the ring, rising from dark.
    final light = Curves.easeInOut.transform(standby.value);
    if (light > 0) {
      canvas.drawCircle(
        center,
        r - _stroke - 2.5,
        Paint()..color = color.withValues(alpha: 0.42 * light),
      );
    }
  }

  @override
  bool shouldRepaint(_GoodbyeDotPainter old) => old.color != color;
}
