import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/social_providers.dart';
import '../../app/theme.dart';
import '../../core/day.dart';
import '../../core/ids.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../domain/services/quick_entry_parser.dart';
import '../../domain/social/account.dart';
import '../../domain/social/shared_bill.dart';
import '../../shared/region_keys.dart';
import '../categories/category_editor_sheet.dart';
import '../people/bill_sheet.dart';
import '../people/split_picker_sheet.dart';
import 'edit_history_sheet.dart';

/// Opens an entry: shared bills open their bill details, everything else
/// the add / edit sheet. Returns true when something was saved or deleted.
Future<bool?> showEntryEditor(BuildContext context, {LedgerEntry? entry, DateTime? date}) async {
  final billId = entry?.billId;
  if (billId != null && ProviderScope.containerOf(context).read(billMapProvider)[billId] != null) {
    await showBillSheet(context, billId);
    return null;
  }
  return showEntryForm(context, entry: entry, date: date);
}

/// The add / edit sheet itself.
Future<bool?> showEntryForm(BuildContext context, {LedgerEntry? entry, DateTime? date}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => EntryEditorSheet(entry: entry, initialDate: date),
  );
}

class EntryEditorSheet extends ConsumerStatefulWidget {
  const EntryEditorSheet({super.key, this.entry, this.initialDate});

  final LedgerEntry? entry;
  final DateTime? initialDate;

  @override
  ConsumerState<EntryEditorSheet> createState() => _EntryEditorSheetState();
}

class _EntryEditorSheetState extends ConsumerState<EntryEditorSheet> {
  late final TextEditingController _note;
  late final TextEditingController _amount; // e.g. "46.5"
  late DateTime _date;
  String? _categoryId;
  SplitChoice _split = SplitChoice.none;

  /// The shared bill being edited, if this entry is one you paid.
  SharedBill? _bill;
  bool _moneyBack = false;
  bool _categoryPickedByUser = false;

  /// True while the split came from typing "split" in the note.
  bool _splitFromNote = false;
  CategorySuggestion? _suggestion;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _note = TextEditingController(text: e?.note ?? '');
    _amount = TextEditingController(text: e == null ? '' : _centsToText(e.amountCents.abs()));
    _date = e?.date ?? dateOnly(widget.initialDate ?? DateTime.now());
    _categoryId = e?.categoryId;
    _categoryPickedByUser = e != null;
    _moneyBack = e?.isMoneyBack ?? false;
    final me = ref.read(accountProvider).value?.uid;
    final bill = e?.billId == null ? null : ref.read(billMapProvider)[e!.billId];
    if (bill != null && bill.createdBy == me) {
      _bill = bill;
      _split = SplitChoice(
        people: [
          for (final uid in bill.members)
            if (uid != me) bill.people[uid] ?? Profile(uid: uid, handle: '', name: 'Someone'),
        ],
        guestNames: bill.guestNames,
        unnamed: bill.guests - bill.guestNames.length,
        memo: bill.memo,
      );
    } else {
      _split = e == null ? SplitChoice.none : SplitChoice.of(e);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickSplit() async {
    final choice = await showSplitPicker(
      context,
      initial: _split,
      cents: _cents,
      money: ref.read(moneyFormatProvider),
    );
    if (choice == null || !mounted) return;
    setState(() {
      _split = choice;
      _splitFromNote = false;
      if (choice.isShared) _moneyBack = false;
    });
  }

  static String _centsToText(int cents) {
    final whole = cents ~/ 100, frac = cents % 100;
    return frac == 0
        ? '$whole'
        : '$whole.${frac.toString().padLeft(2, '0')}'.replaceAll(RegExp(r'0$'), '');
  }

  int get _cents => ((double.tryParse(_amount.text) ?? 0) * 100).round();

  void _onNoteChanged(String text) {
    final parsed = QuickEntryParser.parse(text, knownNames: ref.read(settingsProvider).savedGuests);
    final suggester = ref.read(categorySuggesterProvider).value;
    final allowed = {for (final c in ref.read(activeCategoriesProvider)) c.id};
    setState(() {
      if (parsed.amountCents != null) _amount.text = _centsToText(parsed.amountCents!);
      // The note drives the split until the picker is used.
      if (!_split.isSplit || _splitFromNote) {
        _split = parsed.splitWays > 1
            ? SplitChoice(
                guestNames: parsed.guestNames,
                unnamed: parsed.splitWays - 1 - parsed.guestNames.length,
              )
            : SplitChoice.none;
        _splitFromNote = parsed.splitWays > 1;
      }
      if (parsed.moneyBack) _moneyBack = true;
      _suggestion = suggester?.suggest(text, allowedIds: allowed);
      if (!_categoryPickedByUser && _suggestion != null) _categoryId = _suggestion!.categoryId;
    });
  }

  Future<void> _newCategory() async {
    final created = await showCategoryEditor(context);
    if (created != null && mounted) {
      setState(() {
        _categoryId = created.id;
        _categoryPickedByUser = true;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final cents = _cents;
    if (cents <= 0 || _categoryId == null) return;
    final raw = _note.text;
    // Keep the note readable: drop the amount and keywords if typed inline.
    final parsed = QuickEntryParser.parse(raw, knownNames: ref.read(settingsProvider).savedGuests);
    final note = parsed.amountCents != null ? parsed.note : raw.trim();
    final id = widget.entry?.id ?? newId();
    final billId = await _saveBill(id, cents, note);
    final entry = LedgerEntry(
      id: id,
      amountCents: _moneyBack ? -cents : cents,
      categoryId: _categoryId!,
      date: _date,
      note: note,
      splitWays: _split.ways,
      guestNames: _split.guestNames,
      billId: billId,
      createdAt: widget.entry?.createdAt,
    );
    await ref.read(entryRepositoryProvider).save(entry);
    if (mounted) Navigator.of(context).pop(true);
  }

  /// Shares the bill with the people picked, or stops sharing it. Returns
  /// the bill id when it is shared.
  Future<String?> _saveBill(String id, int cents, String note) async {
    final backend = ref.read(socialBackendProvider);
    final me = ref.read(myProfileProvider).value;
    final existing = _bill;
    final now = DateTime.now();
    if (backend == null || me == null) return null;
    if (!_split.isShared) {
      if (existing != null) await backend.saveBill(existing.copyWith(deleted: true, editedAt: now));
      return null;
    }
    final members = [me.uid, for (final p in _split.people) p.uid];
    final people = {me.uid: me, for (final p in _split.people) p.uid: p};
    final currency = ref.read(settingsProvider).currencyCode;
    final bill = existing == null
        ? SharedBill(
            id: id,
            createdBy: me.uid,
            members: members,
            people: people,
            guests: _split.guests,
            guestNames: _split.guestNames,
            amountCents: cents,
            currencyCode: currency,
            date: _date,
            note: note,
            memo: _split.memo,
            categoryId: _categoryId!,
            createdAt: now,
            editedAt: now,
          )
        : existing.edited(
            members: members,
            people: people,
            guests: _split.guests,
            guestNames: _split.guestNames,
            amountCents: cents,
            currencyCode: existing.currencyCode,
            date: _date,
            note: note,
            memo: _split.memo,
            categoryId: _categoryId!,
            at: now,
          );
    await backend.saveBill(bill);
    return id;
  }

  Future<void> _delete() async {
    final bill = _bill;
    if (bill != null) {
      await ref
          .read(socialBackendProvider)
          ?.saveBill(bill.copyWith(deleted: true, editedAt: DateTime.now()));
    }
    await ref.read(entryRepositoryProvider).delete(widget.entry!.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final money = ref.watch(moneyFormatProvider);
    final settings = ref.watch(settingsProvider);
    final categories = ref.watch(activeCategoriesProvider);
    final categoryMap = ref.watch(categoryMapProvider);
    ref.watch(categorySuggesterProvider); // warm up suggestions
    final selected = categoryMap[_categoryId];
    final cents = _cents;
    final share = (cents / _split.ways).round();
    final splitNames = _split.describe();
    final example = settings.splitsBills
        ? 'costco 46 split${settings.savedGuests.isEmpty ? '' : ' ${settings.savedGuests.first.split(' ').first.toLowerCase()}'}'
        : 'kroger 18';
    final canSave = cents > 0 && _categoryId != null;

    // Most used first; keep the selected one even if it was archived since.
    final usage = ref.watch(categoryUsageProvider).value ?? const {};
    final shown = [...categories, if (selected != null && selected.archived) selected]
      ..sort((a, b) {
        final byUse = (usage[b.id] ?? 0).compareTo(usage[a.id] ?? 0);
        return byUse != 0 ? byUse : a.sortOrder.compareTo(b.sortOrder);
      });

    Widget chip(Category cat) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text('${cat.emoji}  ${cat.name}'),
        selected: cat.id == _categoryId,
        onSelected: (_) => setState(() {
          _categoryId = cat.id;
          _categoryPickedByUser = true;
        }),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _bill != null
                              ? 'Edit shared bill'
                              : (_isEditing ? 'Edit entry' : 'New entry'),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.calendar_today_rounded, size: 16),
                        label: Text(_dateLabel(_date)),
                        onPressed: _pickDate,
                      ),
                      if (_isEditing)
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: _delete,
                          icon: Icon(Icons.delete_outline_rounded, color: c.warn),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Amount: the phone's number pad opens on it.
                  _AmountField(
                    key: RegionKeys.entryAmount,
                    controller: _amount,
                    symbol: _moneyBack ? '+${money.symbol}' : money.symbol,
                    color: _moneyBack ? c.lived : c.ink,
                    autofocus: !_isEditing,
                    onChanged: (_) => setState(() {}),
                  ),
                  SizedBox(
                    height: 20,
                    child: Center(
                      child: Text(
                        key: RegionKeys.shareLine,
                        _split.isSplit && cents > 0
                            ? 'Your share ${money(share)}'
                                  '${splitNames.isEmpty ? '' : ' · $splitNames ${_split.ways == 2 ? 'owes' : 'owe'} ${money(cents - share)}'}'
                            : '',
                        style: TextStyle(color: c.lived, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: RegionKeys.quickEntry,
                    controller: _note,
                    onChanged: _onNoteChanged,
                    groupId: _AmountField.group,
                    onTapOutside: _AmountField.closeKeyboard,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.auto_awesome_rounded, color: c.lived, size: 18),
                      hintText: 'Note, or type it all: $example',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                    child: Text(
                      _suggestion != null && _suggestion!.categoryId == _categoryId
                          ? '${selected?.name} · you used it ${_suggestion!.timesUsed}× for “${_suggestion!.matchedWord}”'
                          : 'Category is picked from how you logged similar notes before.',
                      style: TextStyle(fontSize: 12, color: c.muted),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Two rows that scroll sideways keep the sheet short.
                  SingleChildScrollView(
                    key: RegionKeys.entryCategories,
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [for (var i = 0; i < shown.length; i += 2) chip(shown[i])]),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            for (var i = 1; i < shown.length; i += 2) chip(shown[i]),
                            ActionChip(
                              avatar: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('New'),
                              onPressed: _newCategory,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _OptionTile(
                          title: _split.isSplit ? 'Split ${_split.ways} ways' : 'Split bill',
                          subtitle: !_split.isSplit
                              ? 'tap to choose'
                              : (splitNames.isEmpty ? 'tap to change' : 'with $splitNames'),
                          on: _split.isSplit,
                          onTap: _pickSplit,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _OptionTile(
                          title: 'Money back',
                          subtitle: _split.isShared ? 'not for shared bills' : 'refund, share paid',
                          on: _moneyBack,
                          onTap: _split.isShared
                              ? null
                              : () => setState(() => _moneyBack = !_moneyBack),
                        ),
                      ),
                    ],
                  ),
                  if (widget.entry case final entry? when entry.billId == null)
                    EditHistoryLink(
                      edits: ref.watch(entryEditsProvider(entry.id)).value ?? const [],
                      onTap: () => showEditHistorySheet(
                        context,
                        edits: ref.read(entryEditsProvider(entry.id)).value ?? const [],
                        currencyCode: settings.currencyCode,
                        created: entry.createdAt == null
                            ? 'Created on this device'
                            : 'Created ${DateFormat.yMMMd().format(entry.createdAt!)}',
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          // Always visible, even on small screens or with the keyboard open.
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: FilledButton(
              key: RegionKeys.saveButton,
              onPressed: canSave ? _save : null,
              child: Text(
                canSave
                    ? '${_split.isShared ? 'Share' : 'Save'} ${money(_split.isSplit ? share : cents)} · ${selected?.name ?? ''}'
                    : (_categoryId == null && cents > 0 ? 'Pick a category' : 'Save'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _dateLabel(DateTime d) {
    final today = dateOnly(DateTime.now());
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat(d.year == today.year ? 'MMM d' : 'MMM d, y').format(d);
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.subtitle,
    required this.on,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: on ? c.livedSoft : c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: on ? c.lived : c.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                    Text(subtitle, style: TextStyle(fontSize: 11.5, color: c.muted)),
                  ],
                ),
              ),
              Icon(
                on ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 20,
                color: on ? c.lived : c.line,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The big amount at the top of the sheet. A real text field, so the
/// phone's own number pad opens on it; it grows with the number so the
/// currency symbol stays right next to it.
class _AmountField extends StatelessWidget {
  const _AmountField({
    super.key,
    required this.controller,
    required this.symbol,
    required this.color,
    required this.autofocus,
    required this.onChanged,
  });

  /// Shared by the sheet's text fields: tapping from one to the other keeps
  /// the keyboard up, tapping anywhere else puts it away.
  static const group = _AmountField;

  static void closeKeyboard(PointerDownEvent _) => FocusManager.instance.primaryFocus?.unfocus();

  final TextEditingController controller;
  final String symbol;
  final Color color;
  final bool autofocus;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = TextStyle(
      fontSize: 52,
      fontWeight: FontWeight.w600,
      letterSpacing: -2,
      color: color,
      fontFeatures: tabularFigures,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(symbol, style: TextStyle(fontSize: 30, color: c.muted)),
        Flexible(
          child: IntrinsicWidth(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              onChanged: onChanged,
              groupId: group,
              onTapOutside: closeKeyboard,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              inputFormatters: const [AmountInputFormatter()],
              style: style,
              cursorColor: c.lived,
              cursorHeight: 44,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: style.copyWith(color: c.line),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Keeps the amount to digits and one decimal point with up to two places
/// (at most 9 digits before it). A comma, which some number pads show as the
/// decimal key, is read as a point.
class AmountInputFormatter extends TextInputFormatter {
  const AmountInputFormatter();

  static final _valid = RegExp(r'^\d{0,9}(\.\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(',', '.');
    if (!_valid.hasMatch(text)) return oldValue;
    return newValue.copyWith(text: text);
  }
}
