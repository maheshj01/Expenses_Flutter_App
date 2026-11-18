import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../shared/animations/fade_slide_in.dart';
import '../../shared/animations/motion.dart';
import '../../shared/animations/pressable_scale.dart';

/// Title, subtitle and body of one onboarding question, entering in a
/// short stagger.
class StepLayout extends StatelessWidget {
  const StepLayout({super.key, required this.title, this.subtitle, required this.children});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    var i = 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        FadeSlideIn(
          index: i++,
          child: Text(
            title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8),
          ),
        ),
        if (subtitle != null)
          FadeSlideIn(
            index: i++,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(subtitle!, style: TextStyle(color: c.muted, fontSize: 15, height: 1.4)),
            ),
          ),
        const SizedBox(height: 24),
        for (final child in children) FadeSlideIn(index: i++, child: child),
      ],
    );
  }
}

/// Large whole-number money input.
class AmountInput extends StatefulWidget {
  const AmountInput({
    super.key,
    required this.symbol,
    required this.cents,
    required this.onChanged,
    this.autofocus = false,
    this.hint = '0',
    this.fontSize = 44,
  });

  final String symbol;
  final int cents;
  final ValueChanged<int> onChanged;
  final bool autofocus;
  final String hint;
  final double fontSize;

  @override
  State<AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<AmountInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.cents > 0 ? '${widget.cents ~/ 100}' : '',
  );

  @override
  void didUpdateWidget(AmountInput old) {
    super.didUpdateWidget(old);
    // Reflect values set from outside, like tapping a suggestion.
    final current = int.tryParse(_controller.text) ?? 0;
    if (widget.cents ~/ 100 != current) {
      final text = widget.cents > 0 ? '${widget.cents ~/ 100}' : '';
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
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
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(9),
      ],
      style: TextStyle(
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.5,
        fontFeatures: tabularFigures,
      ),
      decoration: InputDecoration(
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        prefixText: '${widget.symbol} ',
        prefixStyle: TextStyle(
          fontSize: widget.fontSize * 0.6,
          color: c.muted,
          fontWeight: FontWeight.w500,
        ),
        hintText: widget.hint,
        hintStyle: TextStyle(fontSize: widget.fontSize, color: c.line),
      ),
      onChanged: (v) => widget.onChanged((int.tryParse(v) ?? 0) * 100),
    );
  }
}

/// A tappable card with an animated selected state.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.selected,
    required this.onTap,
    required this.title,
    this.emoji,
    this.subtitle,
    this.dense = false,
  });

  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String? emoji;
  final String? subtitle;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressableScale(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        curve: Motion.enter,
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: dense ? 12 : 16),
        decoration: BoxDecoration(
          color: selected ? c.livedSoft : c.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? c.lived : c.line, width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!, style: TextStyle(color: c.muted, fontSize: 12.5)),
                    ),
                ],
              ),
            ),
            AnimatedScale(
              scale: selected ? 1 : 0,
              duration: Motion.of(context, Motion.medium),
              curve: Motion.emphasized,
              child: Icon(Icons.check_circle_rounded, color: c.lived),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill used for quick suggestions ("60% · $2,340").
class SuggestionPill extends StatelessWidget {
  const SuggestionPill({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.ink : c.card,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? c.ink : c.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? c.background : c.ink2,
            fontFeatures: tabularFigures,
          ),
        ),
      ),
    );
  }
}

/// Compact square-ish choice for grids: emoji, short label, check badge.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressableScale(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        curve: Motion.enter,
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: selected ? c.livedSoft : c.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? c.lived : c.line, width: selected ? 1.6 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const Spacer(),
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: Motion.of(context, Motion.medium),
                  curve: Motion.emphasized,
                  child: Icon(Icons.check_circle_rounded, color: c.lived, size: 20),
                ),
              ],
            ),
            const Spacer(),
            Text(
              label,
              maxLines: 2,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}
