import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/import/spreadsheet_reader.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../domain/import/import_plan.dart';
import '../../domain/import/import_runner.dart';
import '../../domain/import/raw_sheet.dart';
import '../../shared/animations/animated_amount.dart';
import '../../shared/animations/fade_slide_in.dart';
import '../../shared/animations/motion.dart';
import '../../shared/widgets/app_card.dart';
import 'data_io_providers.dart';
import 'import_widgets.dart';

enum _Stage { pick, review, done }

/// Brings entries in from a spreadsheet: pick a file, check what was found,
/// then import. Every import can be undone right after.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  _Stage _stage = _Stage.pick;
  bool _busy = false;
  String? _error;

  String _fileName = '';
  List<SheetChoice> _sheets = const [];
  List<LedgerEntry> _existing = const [];
  final Map<String, Category> _overrides = {};
  bool _includeDuplicates = false;
  ImportPlan? _plan;
  ImportResult? _result;
  bool _undone = false;

  List<Category> get _categories => ref.read(categoriesProvider).value ?? const [];

  void _replan() {
    _plan = ImportPlanner.build(
      sheets: _sheets,
      categories: _categories,
      existing: _existing,
      overrides: _overrides,
      includeDuplicates: _includeDuplicates,
    );
  }

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await ref.read(spreadsheetPickerProvider)();
      if (file == null) return;
      final sheets = await compute(_read, file);
      final found = SheetChoice.detect(sheets);
      if (!found.any((s) => s.mapping != null)) {
        throw const SpreadsheetReadError(
          'No sheet has both a Date and an Amount column. Add those headers and try again.',
        );
      }
      _existing = await ref
          .read(entryRepositoryProvider)
          .watchBetween(DateTime(1900), DateTime(2200))
          .first;
      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _sheets = found;
        _overrides.clear();
        _includeDuplicates = false;
        _replan();
        _stage = _Stage.review;
      });
    } on SpreadsheetReadError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static List<RawSheet> _read(PickedFile file) => readSpreadsheet(file.bytes, file.name);

  Future<void> _import() async {
    final plan = _plan;
    if (plan == null || plan.entries.isEmpty) return;
    setState(() => _busy = true);
    final result = await ref.read(importRunnerProvider).apply(plan);
    await HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() {
      _result = result;
      _busy = false;
      _stage = _Stage.done;
    });
  }

  Future<void> _undo() async {
    final result = _result;
    if (result == null) return;
    setState(() => _busy = true);
    await ref.read(importRunnerProvider).undo(result);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _undone = true;
    });
  }

  void _update(VoidCallback change) => setState(() {
    change();
    _replan();
  });

  @override
  Widget build(BuildContext context) {
    final body = switch (_stage) {
      _Stage.pick => _PickStage(busy: _busy, error: _error, onPick: _pick),
      _Stage.review => _review(context),
      _Stage.done => _DoneStage(
        result: _result!,
        plan: _plan!,
        undone: _undone,
        busy: _busy,
        onUndo: _undo,
      ),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(_stage == _Stage.review ? 'Check your import' : 'Import'),
        leading: _stage == _Stage.review
            ? IconButton(
                tooltip: 'Choose another file',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _stage = _Stage.pick),
              )
            : null,
      ),
      body: AnimatedSwitcher(
        duration: Motion.of(context, Motion.medium),
        switchInCurve: Motion.enter,
        switchOutCurve: Motion.exit,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(a),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(_stage), child: body),
      ),
    );
  }

  Widget _review(BuildContext context) {
    final c = context.colors;
    final plan = _plan!;
    final money = ref.watch(moneyFormatProvider);
    final usable = [
      for (final s in _sheets)
        if (s.mapping != null) s,
    ];
    final skipped = [
      for (final s in _sheets)
        if (s.mapping == null) s.sheet.name,
    ];
    final range = plan.firstDate == null
        ? 'Nothing selected yet'
        : _range(plan.firstDate!, plan.lastDate!);
    final maxMonth = plan.months.fold(1, (m, t) => t.cents.abs() > m ? t.cents.abs() : m);
    var i = 0;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            children: [
              FadeSlideIn(
                index: i++,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description_outlined, size: 16, color: c.muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.muted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AnimatedAmount(
                      cents: plan.entries.length,
                      duration: Motion.medium,
                      builder: (context, n) => Text(
                        '$n ${n == 1 ? 'entry' : 'entries'}',
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(range, style: TextStyle(color: c.ink2)),
                  ],
                ),
              ),
              const SectionHeader('Sheets'),
              FadeSlideIn(
                index: i++,
                child: AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (final (n, s) in usable.indexed) ...[
                        if (n > 0) const Divider(indent: 56),
                        SheetTile(
                          choice: s,
                          onToggle: (on) => _update(() {
                            _sheets = [
                              for (final x in _sheets) x == s ? x.copyWith(included: on) : x,
                            ];
                          }),
                          onEditColumns: () async {
                            final mapping = await showColumnEditor(context, s);
                            if (mapping == null) return;
                            _update(() {
                              _sheets = [
                                for (final x in _sheets) x == s ? x.copyWith(mapping: mapping) : x,
                              ];
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (skipped.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    'Skipped ${skipped.join(', ')}: no Date and Amount columns.',
                    style: TextStyle(color: c.muted, fontSize: 12.5),
                  ),
                ),
              if (plan.groups.isNotEmpty) ...[
                const SectionHeader('Categories'),
                FadeSlideIn(
                  index: i++,
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (final (n, g) in plan.groups.indexed) ...[
                          if (n > 0) const Divider(indent: 16),
                          CategoryGroupTile(
                            group: g,
                            money: money,
                            onTap: () async {
                              final picked = await showCategoryTargetPicker(
                                context,
                                group: g,
                                categories: _categories,
                              );
                              if (picked != null) _update(() => _overrides[g.key] = picked);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              if (plan.duplicates > 0) ...[
                const SizedBox(height: 16),
                FadeSlideIn(
                  index: i++,
                  child: AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${plan.duplicates} already in Three Bucks',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                _includeDuplicates
                                    ? 'Importing them anyway'
                                    : 'Same day and amount as an entry you have. Skipped.',
                                style: TextStyle(color: c.muted, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _includeDuplicates,
                          onChanged: (on) => _update(() => _includeDuplicates = on),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (plan.problems.isNotEmpty) ...[
                const SizedBox(height: 16),
                FadeSlideIn(
                  index: i++,
                  child: ProblemsCard(problems: plan.problems),
                ),
              ],
              if (plan.months.isNotEmpty) ...[
                const SectionHeader('By month'),
                FadeSlideIn(
                  index: i++,
                  child: AppCard(
                    child: Column(
                      children: [
                        for (final (n, m) in plan.months.indexed)
                          FadeSlideIn(
                            index: n,
                            child: MonthBar(total: m, max: maxMonth, money: money),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
                child: Text(
                  'Amounts are read as ${ref.watch(settingsProvider).currencyCode}. Negative '
                  'amounts count as money back. Importing the same file again won’t add '
                  'anything twice.',
                  style: TextStyle(color: c.muted, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: SafeArea(
            top: false,
            child: FilledButton(
              onPressed: _busy || plan.entries.isEmpty ? null : _import,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      plan.entries.isEmpty
                          ? 'Nothing to import'
                          : 'Import ${plan.entries.length} ${plan.entries.length == 1 ? 'entry' : 'entries'}',
                    ),
            ),
          ),
        ),
      ],
    );
  }

  static String _range(DateTime a, DateTime b) {
    final short = DateFormat.MMMd();
    if (a.year == b.year) return '${short.format(a)} – ${short.format(b)}, ${b.year}';
    final long = DateFormat.yMMMd();
    return '${long.format(a)} – ${long.format(b)}';
  }
}

class _PickStage extends StatelessWidget {
  const _PickStage({required this.busy, required this.error, required this.onPick});

  final bool busy;
  final String? error;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        const FadeSlideIn(child: SheetIllustration()),
        const SizedBox(height: 28),
        const FadeSlideIn(
          index: 1,
          child: Text(
            'Bring in your spreadsheet',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        FadeSlideIn(
          index: 2,
          child: Text(
            'Pick an .xlsx or .csv file. We’ll find the sheets with a Date and an Amount '
            'column, match your categories, and show you everything before saving.',
            style: TextStyle(color: c.ink2, fontSize: 15, height: 1.4),
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          index: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final tip in const [
                'One tab per month is fine. Every tab is read.',
                'Google Sheets: File → Download → Microsoft Excel (.xlsx).',
                'Bank exports work too, as long as they have Date and Amount.',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_rounded, size: 18, color: c.lived),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(tip, style: TextStyle(color: c.ink2)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        AnimatedSize(
          duration: Motion.of(context, Motion.medium),
          curve: Motion.enter,
          child: error == null
              ? const SizedBox(width: double.infinity)
              : Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.warnSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(error!, style: TextStyle(color: c.warn)),
                ),
        ),
        const SizedBox(height: 24),
        FadeSlideIn(
          index: 4,
          child: FilledButton.icon(
            onPressed: busy ? null : onPick,
            icon: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_rounded),
            label: Text(busy ? 'Reading…' : 'Choose file'),
          ),
        ),
      ],
    );
  }
}

class _DoneStage extends StatelessWidget {
  const _DoneStage({
    required this.result,
    required this.plan,
    required this.undone,
    required this.busy,
    required this.onUndo,
  });

  final ImportResult result;
  final ImportPlan plan;
  final bool undone;
  final bool busy;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final months = plan.months.length;
    final created = result.createdCategoryIds.length;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Motion.of(context, Motion.slow),
            curve: Motion.emphasized,
            builder: (context, t, child) => Transform.scale(scale: t, child: child),
            child: AnimatedContainer(
              duration: Motion.of(context, Motion.medium),
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: undone ? c.sunk : c.livedSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                undone ? Icons.undo_rounded : Icons.check_rounded,
                size: 48,
                color: undone ? c.muted : c.lived,
              ),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: Motion.of(context, Motion.medium),
            child: Text(
              undone
                  ? 'Import undone'
                  : 'Imported ${result.count} ${result.count == 1 ? 'entry' : 'entries'}',
              key: ValueKey(undone),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          FadeSlideIn(
            index: 1,
            child: Text(
              undone
                  ? 'Nothing from the file is left in Three Bucks.'
                  : [
                      'Across $months ${months == 1 ? 'month' : 'months'}. See them in History.',
                      if (created > 0)
                        'Added $created new ${created == 1 ? 'category' : 'categories'}.',
                    ].join(' '),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.ink2, fontSize: 15),
            ),
          ),
          const Spacer(),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
          const SizedBox(height: 8),
          AnimatedOpacity(
            opacity: undone ? 0 : 1,
            duration: Motion.of(context, Motion.fast),
            child: TextButton(
              onPressed: undone || busy ? null : onUndo,
              style: TextButton.styleFrom(foregroundColor: c.warn),
              child: const Text('Undo import'),
            ),
          ),
        ],
      ),
    );
  }
}
