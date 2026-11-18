import 'package:flutter/widgets.dart';

/// Shared timing for all motion in the app, so everything feels related.
abstract final class Motion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 650);

  /// Delay between items that enter one after another.
  static const stagger = Duration(milliseconds: 60);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const emphasized = Curves.easeOutBack;

  /// Zero when the user asked the OS to reduce motion.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}
