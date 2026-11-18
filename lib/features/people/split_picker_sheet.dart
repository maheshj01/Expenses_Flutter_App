import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/social_providers.dart';
import '../../app/theme.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../domain/social/account.dart';
import '../../shared/animations/fade_slide_in.dart';
import '../../shared/animations/motion.dart';
import '../../shared/money_format.dart';

/// Who a bill is split with: people on the app and people who aren't.
class SplitChoice {
  const SplitChoice({
    this.people = const [],
    this.guestNames = const [],
    this.unnamed = 0,
    this.memo = '',
  });

  /// How a personal entry was split.
  factory SplitChoice.of(LedgerEntry entry) => SplitChoice(
    guestNames: entry.guestNames,
    unnamed: math.max(0, entry.splitWays - 1 - entry.guestNames.length),
  );

  static const none = SplitChoice();

  final List<Profile> people;

  /// People not on the app, by name. Only your share is tracked for them.
  final List<String> guestNames;

  /// People not on the app you didn't name.
  final int unnamed;

  /// Optional note for the people on the app, e.g. "I covered the tip".
  final String memo;

  /// Everyone not on the app.
  int get guests => guestNames.length + unnamed;

  /// Ways the bill is split, you included.
  int get ways => 1 + people.length + guests;

  bool get isSplit => ways > 1;

  bool get isShared => people.isNotEmpty;

  SplitChoice copyWith({List<String>? guestNames, int? unnamed}) => SplitChoice(
    people: people,
    guestNames: guestNames ?? this.guestNames,
    unnamed: unnamed ?? this.unnamed,
    memo: memo,
  );

  /// "Sam and Ana", "Sam +1", or "" when nobody is named.
  String describe() => describeSplit([
    for (final p in people) p.name.isEmpty ? '@${p.handle}' : p.name.split(' ').first,
    ...guestNames,
  ], unnamed);
}

/// "Sam", "Sam and Ana", "Sam, Ana and Lee", plus "+n" for unnamed people.
String describeSplit(List<String> names, int unnamed) {
  if (names.isEmpty) return '';
  final listed = names.length == 1
      ? names.first
      : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  return unnamed == 0 ? listed : '$listed +$unnamed';
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
  late final List<String> _guestNames = [...widget.initial.guestNames];
  late int _unnamed = widget.initial.unnamed;
  late final _memo = TextEditingController(text: widget.initial.memo);
  final _newName = TextEditingController();
  bool _adding = false;

  SplitChoice get _choice => SplitChoice(
    people: _people.values.toList(),
    guestNames: _guestNames,
    unnamed: _unnamed,
    memo: _memo.text.trim(),
  );

  static const _maxGuests = 19;

  bool get _full => _guestNames.length + _unnamed >= _maxGuests;

  @override
  void dispose() {
    _memo.dispose();
    _newName.dispose();
    super.dispose();
  }

  bool _picked(String name) => _guestNames.any((n) => n.toLowerCase() == name.toLowerCase());

  void _toggleGuest(String name, bool on) => setState(() {
    if (on) {
      if (!_picked(name) && !_full) _guestNames.add(name);
    } else {
      _guestNames.removeWhere((n) => n.toLowerCase() == name.toLowerCase());
    }
  });

  /// Adds a new person not on the app, picks them and saves them for next time.
  Future<void> _addGuest() async {
    final name = _newName.text.trim();
    if (name.isEmpty) {
      setState(() => _adding = false);
      return;
    }
    _toggleGuest(name, true);
    setState(() {
      _adding = false;
      _newName.clear();
    });
    final settings = ref.read(settingsProvider);
    await ref
        .read(settingsProvider.notifier)
        .update(settings.copyWith(savedGuests: settings.withGuests([name])));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final friends = ref.watch(friendsProvider);
    final signedIn = ref.watch(myProfileProvider).value != null;
    final saved = ref.watch(settingsProvider.select((s) => s.savedGuests));
    // Saved people first, then anyone named on this bill but no longer saved.
    final guestOptions = [
      ...saved,
      for (final n in widget.initial.guestNames)
        if (!saved.any((s) => s.toLowerCase() == n.toLowerCase())) n,
    ];
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
          const Text('Not on the app', style: TextStyle(fontWeight: FontWeight.w600)),
          Text(
            _people.isEmpty
                ? 'Only your share is tracked for them.'
                : 'Only your share is tracked for them. Names show on the shared bill.',
            style: TextStyle(color: c.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, name) in guestOptions.indexed)
                FadeSlideIn(
                  key: ValueKey('guest-$name'),
                  index: i,
                  child: FilterChip(
                    label: Text(name),
                    labelStyle: TextStyle(
                      color: _picked(name) ? c.background : c.ink2,
                      fontWeight: FontWeight.w600,
                    ),
                    selected: _picked(name),
                    onSelected: (on) => _toggleGuest(name, on),
                  ),
                ),
              if (!_adding)
                ActionChip(
                  avatar: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Add name'),
                  onPressed: _full ? null : () => setState(() => _adding = true),
                ),
            ],
          ),
          AnimatedSize(
            duration: Motion.of(context, Motion.medium),
            curve: Motion.enter,
            alignment: Alignment.topCenter,
            child: !_adding
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextField(
                      controller: _newName,
                      autofocus: true,
                      maxLength: 40,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addGuest(),
                      decoration: InputDecoration(
                        isDense: true,
                        counterText: '',
                        hintText: 'Their name, e.g. your roommate',
                        suffixIcon: IconButton(
                          tooltip: 'Add',
                          icon: const Icon(Icons.check_rounded),
                          onPressed: _addGuest,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _guestNames.isEmpty ? 'People, unnamed' : 'Others, unnamed',
                  style: TextStyle(color: c.ink2),
                ),
              ),
              IconButton.outlined(
                tooltip: 'Fewer',
                onPressed: _unnamed == 0 ? null : () => setState(() => _unnamed--),
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(
                width: 36,
                child: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.fast),
                  transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                  child: Text(
                    '$_unnamed',
                    key: ValueKey(_unnamed),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              IconButton.outlined(
                tooltip: 'More',
                onPressed: _full ? null : () => setState(() => _unnamed++),
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
