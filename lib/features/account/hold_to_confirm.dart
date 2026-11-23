import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A button that has to be held, not tapped, before it acts: the colour
/// fills from the left while the finger stays down and drains back if it
/// lifts early. For the one action in the app that can't be taken back, a
/// deliberate gesture instead of a typed "DELETE".
///
/// Screen readers get the same action as a long press.
class HoldToConfirm extends StatefulWidget {
  const HoldToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    required this.color,
    this.holdingLabel = 'Keep holding…',
    this.busyLabel = 'Deleting…',
    this.busy = false,
    this.holdFor = const Duration(milliseconds: 1600),
  });

  final String label;
  final String holdingLabel;
  final String busyLabel;
  final Color color;
  final bool busy;
  final VoidCallback onConfirmed;

  /// How long the finger has to stay down.
  final Duration holdFor;

  @override
  State<HoldToConfirm> createState() => _HoldToConfirmState();
}

class _HoldToConfirmState extends State<HoldToConfirm> with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: widget.holdFor,
    reverseDuration: const Duration(milliseconds: 280),
  )..addStatusListener(_onStatus);

  bool get _holding => _fill.status == AnimationStatus.forward;

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      HapticFeedback.heavyImpact();
      widget.onConfirmed();
    }
  }

  void _press() {
    if (widget.busy) return;
    HapticFeedback.selectionClick();
    _fill.forward();
  }

  void _release() {
    if (_fill.status != AnimationStatus.completed) _fill.reverse();
  }

  @override
  void didUpdateWidget(HoldToConfirm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A failed attempt comes back not busy: empty the bar for the next try.
    if (oldWidget.busy && !widget.busy) _fill.value = 0;
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      enabled: !widget.busy,
      label: widget.label,
      onLongPress: widget.busy ? null : widget.onConfirmed,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _press(),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        child: AnimatedBuilder(
          animation: _fill,
          builder: (context, _) {
            final text = widget.busy
                ? widget.busyLabel
                : _holding
                ? widget.holdingLabel
                : widget.label;
            // Two copies of the label, the filled one clipped to the
            // progress, so the text turns white exactly where the fill is.
            Widget face(Color background, Color foreground) => Container(
              height: 56,
              alignment: Alignment.center,
              color: background,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.busy) ...[
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    text,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: foreground),
                  ),
                ],
              ),
            );
            final progress = widget.busy ? 1.0 : Curves.easeIn.transform(_fill.value);
            return ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  face(widget.color.withValues(alpha: 0.10), widget.color),
                  Positioned.fill(
                    child: ClipRect(
                      clipper: _LeftFraction(progress),
                      child: face(widget.color, Colors.white),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LeftFraction extends CustomClipper<Rect> {
  const _LeftFraction(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_LeftFraction oldClipper) => oldClipper.fraction != fraction;
}
