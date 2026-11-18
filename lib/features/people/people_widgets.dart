import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/social/account.dart';
import '../../shared/animations/animated_amount.dart';
import '../../shared/animations/motion.dart';
import '../../shared/money_format.dart';

/// A round avatar with someone's initials, in a color stable per person.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar(this.profile, {super.key, this.size = 40});

  final Profile? profile;
  final double size;

  static const _tints = [
    (Color(0xFFE8F3E4), Color(0xFF2F6B3A)),
    (Color(0xFFEDE9FB), Color(0xFF5B45B0)),
    (Color(0xFFFFF4D6), Color(0xFF8A6100)),
    (Color(0xFFE3EEFB), Color(0xFF285C9C)),
    (Color(0xFFFBE7EE), Color(0xFFA23A62)),
    (Color(0xFFE6F4F3), Color(0xFF26706A)),
  ];

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg) = p == null
        ? (context.colors.sunk, context.colors.muted)
        : _tints[p.uid.hashCode.abs() % _tints.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? fg.withValues(alpha: 0.35) : bg,
        shape: BoxShape.circle,
      ),
      child: Text(
        p?.initials ?? '+',
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: dark ? Colors.white : fg,
        ),
      ),
    );
  }
}

/// "owes you $45.00", "you owe $12.00" or "settled up", counting to new
/// values. One line per currency.
class BalanceText extends StatelessWidget {
  const BalanceText(this.balance, {super.key, this.fontSize = 13, this.alignEnd = true});

  /// Per currency; positive means they owe you.
  final Map<String, int> balance;
  final double fontSize;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (balance.isEmpty) {
      return Text(
        'settled up',
        style: TextStyle(fontSize: fontSize, color: c.muted),
      );
    }
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final MapEntry(key: currency, value: cents) in balance.entries)
          AnimatedAmount(
            cents: cents.abs(),
            builder: (context, value) {
              final amount = MoneyFormat(currency)(value);
              return Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: cents > 0 ? 'owes you ' : 'you owe '),
                    TextSpan(
                      text: amount,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                style: TextStyle(
                  fontSize: fontSize,
                  color: cents > 0 ? c.lived : c.warn,
                  fontFeatures: tabularFigures,
                ),
              );
            },
          ),
      ],
    );
  }
}

/// A small count bubble that pops when the number changes.
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -6,
          top: -4,
          child: AnimatedSwitcher(
            duration: Motion.of(context, Motion.medium),
            switchInCurve: Motion.emphasized,
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: count == 0
                ? const SizedBox.shrink(key: ValueKey(0))
                : Container(
                    key: ValueKey(count),
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: c.warn,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: c.background, width: 2),
                    ),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// A pill such as "Disputed" that pops in.
class PopTag extends StatelessWidget {
  const PopTag(this.text, {super.key, required this.color, required this.background, this.icon});

  final String text;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: Motion.of(context, Motion.medium),
      curve: Motion.emphasized,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: Opacity(opacity: scale.clamp(0, 1), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 3)],
            Text(
              text,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class DisputedTag extends StatelessWidget {
  const DisputedTag({super.key});

  @override
  Widget build(BuildContext context) => PopTag(
    'Disputed',
    icon: Icons.flag_rounded,
    color: context.colors.warn,
    background: context.colors.warnSoft,
  );
}

/// For filled buttons placed in a row; the theme makes them full width.
final compactButton = FilledButton.styleFrom(minimumSize: const Size(0, 40));

/// The link that opens the app on someone's "add me" screen.
Uri inviteLink(String handle) => Uri(scheme: 'threebucks', host: 'add', path: '/$handle');

/// Reads a handle from an invite link, or null if it isn't one.
String? handleFromLink(Uri uri) {
  if (uri.scheme != 'threebucks' || uri.host != 'add') return null;
  final handle = Handle.normalize(uri.pathSegments.firstOrNull ?? '');
  return Handle.validate(handle) == null ? handle : null;
}

String inviteMessage(Profile me) =>
    'I’m @${me.handle} on Three Bucks. Add me so we can split bills: ${inviteLink(me.handle)}';
