import 'package:flutter/material.dart';

import '../../app/theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(22);
    return Material(
      color: color ?? c.card,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text('$action ›', style: TextStyle(fontSize: 13, color: c.muted)),
            ),
        ],
      ),
    );
  }
}

class Label extends StatelessWidget {
  const Label(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      color: color ?? context.colors.muted,
      fontWeight: FontWeight.w500,
    ),
  );
}

/// Horizontal stacked progress bar.
class SegmentBar extends StatelessWidget {
  const SegmentBar({super.key, required this.segments, this.height = 10});

  /// Fractions (0..1) with their colors.
  final List<(double, Color)> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: context.colors.sunk,
        child: LayoutBuilder(
          builder: (context, constraints) {
            var remaining = constraints.maxWidth;
            return Row(
              children: [
                for (final (fraction, color) in segments)
                  if (fraction > 0)
                    Builder(
                      builder: (context) {
                        final width = (constraints.maxWidth * fraction.clamp(0, 1)).clamp(
                          0.0,
                          remaining,
                        );
                        remaining -= width;
                        return Container(width: width, color: color);
                      },
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.emoji, required this.title, this.message});

  final String emoji;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.muted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
