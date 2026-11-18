import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../shared/animations/fade_slide_in.dart';

/// Lists the people not on the app you split with, to add or remove names.
Future<void> showSavedGuestsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _SavedGuestsSheet(),
  );
}

class _SavedGuestsSheet extends ConsumerStatefulWidget {
  const _SavedGuestsSheet();

  @override
  ConsumerState<_SavedGuestsSheet> createState() => _SavedGuestsSheetState();
}

class _SavedGuestsSheetState extends ConsumerState<_SavedGuestsSheet> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save(List<String> names) {
    final settings = ref.read(settingsProvider);
    return ref.read(settingsProvider.notifier).update(settings.copyWith(savedGuests: names));
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    _name.clear();
    await _save(ref.read(settingsProvider).withGuests([name]));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final names = ref.watch(settingsProvider.select((s) => s.savedGuests));

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18, 4, 18, 18 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'People not on the app',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Pick them when you split a bill, or type “costco 46 split sam”. '
            'Removing someone keeps their name on past bills.',
            style: TextStyle(color: c.muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          if (names.isEmpty)
            Text('Nobody yet.', style: TextStyle(color: c.muted))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, name) in names.indexed)
                  FadeSlideIn(
                    key: ValueKey(name),
                    index: i,
                    child: InputChip(
                      label: Text(name),
                      deleteButtonTooltipMessage: 'Remove $name',
                      onDeleted: () => _save([...names]..remove(name)),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(
              isDense: true,
              counterText: '',
              hintText: 'Add a name',
              prefixIcon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              suffixIcon: IconButton(
                tooltip: 'Add',
                icon: const Icon(Icons.check_rounded),
                onPressed: _add,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
