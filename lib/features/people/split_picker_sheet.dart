import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/social_providers.dart';
import '../../app/theme.dart';
import '../../domain/social/account.dart';
import '../../shared/animations/fade_slide_in.dart';
import '../../shared/animations/motion.dart';
import '../../shared/money_format.dart';

/// Who a bill is split with: people on the app and people who aren't.
class SplitChoice {
  const SplitChoice({this.people = const [], this.guests = 0, this.memo = ''});

  static const none = SplitChoice();

  final List<Profile> people;

  /// People not on the app; only your share is tracked for them.
  final int guests;

  /// Optional note for the people on the app, e.g. "I covered the tip".
  final String memo;

  /// Ways the bill is split, you included.
  int get ways => 1 + people.length + guests;

  bool get isSplit => ways > 1;

  bool get isShared => people.isNotEmpty;

  /// "Sam and Ana", "Sam +1", or "Alex" (your usual split partner).
  String describe(String guestName) {
    final names = [
      for (final p in people) p.name.isEmpty ? '@${p.handle}' : p.name.split(' ').first,
    ];
    if (names.isEmpty) {
      // Unnamed people not on the app: nothing useful to say.
      if (guests == 0 || guestName.isEmpty) return '';
      return guests == 1 ? guestName : '$guestName +${guests - 1}';
    }
    final listed = names.length == 1
        ? names.first
        : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    return guests == 0 ? listed : '$listed +$guests';
  }
}

Future<SplitChoice?> showSplitPicker(
  BuildContext context, {
  required SplitChoice initial,
  required int cents,
  required MoneyFormat money,
}) {
  return showModalBottomSheet<SplitChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SplitPicker(initial: initial, cents: cents, money: money),
  );
}

class _SplitPicker extends ConsumerStatefulWidget {
  const _SplitPicker({required this.initial, required this.cents, required this.money});

  final SplitChoice initial;
  final int cents;
  final MoneyFormat money;

  @override
  ConsumerState<_SplitPicker> createState() => _SplitPickerState();
}

class _SplitPickerState extends ConsumerState<_SplitPicker> {
  late final Map<String, Profile> _people = {for (final p in widget.initial.people) p.uid: p};
  late int _guests = widget.initial.guests;
  late final _memo = TextEditingController(text: widget.initial.memo);

  SplitChoice get _choice =>
      SplitChoice(people: _people.values.toList(), guests: _guests, memo: _memo.text.trim());

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final friends = ref.watch(friendsProvider);
    final signedIn = ref.watch(myProfileProvider).value != null;
    final guestName = ref.watch(settingsProvider.select((s) => s.splitWith));
    final choice = _choice;
    final share = (widget.cents / choice.ways).round();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18, 4, 18, 18 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Split with', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (friends.isNotEmpty) ...[
            Text('On Three Bucks', style: TextStyle(color: c.muted, fontSize: 12.5)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, f) in friends.indexed)
                  FadeSlideIn(
                    index: i,
                    child: FilterChip(
                      avatar: CircleAvatar(
                        backgroundColor: c.livedSoft,
                        child: Text(
                          f.other.initials,
                          style: TextStyle(fontSize: 10, color: c.lived),
                        ),
                      ),
                      label: Text(f.other.displayName),
                      labelStyle: TextStyle(
                        color: _people.containsKey(f.other.uid) ? c.background : c.ink2,
                        fontWeight: FontWeight.w600,
                      ),
                      selected: _people.containsKey(f.other.uid),
                      onSelected: (on) => setState(() {
                        if (on) {
                          _people[f.other.uid] = f.other;
                        } else {
                          _people.remove(f.other.uid);
                        }
                      }),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'They’ll see the bill and their share. You’ll see who owes what.',
              style: TextStyle(color: c.muted, fontSize: 12),
            ),
            AnimatedSize(
              duration: Motion.of(context, Motion.medium),
              curve: Motion.enter,
              child: _people.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextField(
                        controller: _memo,
                        maxLength: 120,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          isDense: true,
                          counterText: '',
                          prefixIcon: Icon(Icons.chat_bubble_outline_rounded, size: 18),
                          hintText: 'Add a note for them (optional)',
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
          ] else
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Text('👥', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      signedIn
                          ? 'Add people on the People tab to split with them here.'
                          : 'Want them to see their share? Set up sharing on the People tab.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Not on the app', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      guestName.isEmpty ? 'Only your share is tracked' : 'e.g. $guestName',
                      style: TextStyle(color: c.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              IconButton.outlined(
                tooltip: 'Fewer',
                onPressed: _guests == 0 ? null : () => setState(() => _guests--),
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(
                width: 36,
                child: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.fast),
                  transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                  child: Text(
                    '$_guests',
                    key: ValueKey(_guests),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              IconButton.outlined(
                tooltip: 'More',
                onPressed: _guests >= 9 ? null : () => setState(() => _guests++),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.pop(context, choice),
            child: Text(
              choice.isSplit
                  ? 'Split ${choice.ways} ways${widget.cents > 0 ? ' · your share ${widget.money(share)}' : ''}'
                  : 'Don’t split',
            ),
          ),
          if (choice.isSplit)
            TextButton(
              onPressed: () => Navigator.pop(context, SplitChoice.none),
              child: const Text('Don’t split'),
            ),
        ],
      ),
    );
  }
}
