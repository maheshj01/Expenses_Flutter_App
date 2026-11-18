import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../domain/entities/category.dart';
import '../../domain/import/column_mapping.dart';
import '../../domain/import/import_plan.dart';
import '../../shared/animations/fade_slide_in.dart';
import '../../shared/animations/motion.dart';
import '../../shared/money_format.dart';
import '../../shared/widgets/category_avatar.dart';

/// A little spreadsheet whose rows fill in, one after another.
class SheetIllustration extends StatelessWidget {
  const SheetIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const widths = [0.9, 0.7, 0.8, 0.55, 0.75];
    return Container(
      height: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final w in const [56.0, 70.0, 48.0])
                Container(
                  width: w,
                  height: 10,
                  margin: const EdgeInsets.only(right: 10, bottom: 12),
                  decoration: BoxDecoration(color: c.ink2, borderRadius: BorderRadius.circular(4)),
                ),
            ],
          ),
          for (final (i, w) in widths.indexed)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: w),
              duration: Motion.of(context, Motion.slow) + Motion.stagger * (i * 2),
              curve: Motion.enter,
              builder: (context, t, _) => FractionallySizedBox(
                widthFactor: t,
                child: Container(
                  height: 9,
                  margin: const EdgeInsets.only(bottom: 9),
                  decoration: BoxDecoration(
                    color: i.isEven ? c.livedSoft : c.investedSoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A sheet found in the file, with a switch to include it.
class SheetTile extends StatelessWidget {
  const SheetTile({
    super.key,
    required this.choice,
    required this.onToggle,
    required this.onEditColumns,
  });

  final SheetChoice choice;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEditColumns;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mapping = choice.mapping!;
    final rows = choice.sheet.rows.length - mapping.headerRow - 1;
    final fields = [
      for (final f in ImportField.values)
        if (mapping.columns.containsKey(f)) f.label,
    ];
    return InkWell(
      onTap: onEditColumns,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            AnimatedContainer(
              duration: Motion.of(context, Motion.fast),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: choice.included ? c.livedSoft : c.sunk,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.table_chart_outlined,
                size: 16,
                color: choice.included ? c.lived : c.muted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    choice.sheet.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: choice.included ? c.ink : c.muted,
                    ),
                  ),
                  Text(
                    '${rows < 0 ? 0 : rows} rows · ${fields.join(', ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Switch(value: choice.included, onChanged: onToggle),
          ],
        ),
      ),
    );
  }
}

/// Lets the user say which column holds what.
Future<ColumnMapping?> showColumnEditor(BuildContext context, SheetChoice choice) {
  return showModalBottomSheet<ColumnMapping>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ColumnEditor(choice: choice),
  );
}

class _ColumnEditor extends StatefulWidget {
  const _ColumnEditor({required this.choice});

  final SheetChoice choice;

  @override
  State<_ColumnEditor> createState() => _ColumnEditorState();
}

class _ColumnEditorState extends State<_ColumnEditor> {
  late ColumnMapping _mapping = widget.choice.mapping!;

  String _columnName(int c) {
    final header = widget.choice.sheet.cell(_mapping.headerRow, c);
    final letter = c < 26 ? String.fromCharCode(65 + c) : 'Column ${c + 1}';
    final text = header?.toString().trim() ?? '';
    return text.isEmpty ? 'Column $letter' : '$text ($letter)';
  }

  /// First few values under a column, to help pick the right one.
  String _sample(int c) {
    final s = widget.choice.sheet;
    final values = [
      for (var r = _mapping.headerRow + 1; r < s.rows.length && r < _mapping.headerRow + 4; r++)
        if (s.cell(r, c) != null) s.cell(r, c).toString(),
    ];
    return values.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final header = widget.choice.sheet.rows[_mapping.headerRow];
    final columnCount = header.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Columns in “${widget.choice.sheet.name}”',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Headers are on row ${_mapping.headerRow + 1}.',
            style: TextStyle(color: c.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          for (final (i, field) in ImportField.values.indexed)
            FadeSlideIn(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DropdownButtonFormField<int?>(
                  initialValue: _mapping.columns[field],
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: field.required ? field.label : '${field.label} (optional)',
                    helperText: _mapping.columns[field] == null
                        ? null
                        : _sample(_mapping.columns[field]!),
                    helperMaxLines: 1,
                  ),
                  items: [
                    if (!field.required)
                      const DropdownMenuItem<int?>(value: null, child: Text('Not in this sheet')),
                    for (var col = 0; col < columnCount; col++)
                      DropdownMenuItem<int?>(
                        value: col,
                        child: Text(_columnName(col), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (col) => setState(() => _mapping = _mapping.withColumn(field, col)),
                ),
              ),
            ),
          const SizedBox(height: 6),
          FilledButton(
            onPressed: _mapping.isUsable ? () => Navigator.pop(context, _mapping) : null,
            child: const Text('Use these columns'),
          ),
        ],
      ),
    );
  }
}

/// "Groceries ×117 → 🛒 Food".
class CategoryGroupTile extends StatelessWidget {
  const CategoryGroupTile({
    super.key,
    required this.group,
    required this.money,
    required this.onTap,
  });

  final CategoryGroup group;
  final MoneyFormat money;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontStyle: group.key.isEmpty ? FontStyle.italic : null,
                    ),
                  ),
                  Text(
                    '${group.count} · ${money.whole(group.cents)}',
                    style: TextStyle(color: c.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, size: 16, color: c.muted),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: Motion.of(context, Motion.fast),
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: Row(
                key: ValueKey(group.target.id),
                mainAxisSize: MainAxisSize.min,
                children: [
                  CategoryAvatar(group.target, size: 28),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      group.target.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (group.isNew) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.livedSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('New', style: TextStyle(fontSize: 11, color: c.lived)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks where a category from the file goes: a new one or an existing one.
Future<Category?> showCategoryTargetPicker(
  BuildContext context, {
  required CategoryGroup group,
  required List<Category> categories,
}) {
  final fresh = ImportPlanner.newCategoryFor(
    group.key.isEmpty ? 'Misc' : group.label,
    categories.length,
  );
  final existing = [...categories]
    ..sort((a, b) {
      if (a.archived != b.archived) return a.archived ? 1 : -1;
      return a.sortOrder.compareTo(b.sortOrder);
    });
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      final c = context.colors;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 18),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Text(
                'Put “${group.label}” in',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            if (!existing.any((e) => e.id == fresh.id))
              ListTile(
                leading: CategoryAvatar(fresh, size: 36),
                title: Text('New category “${fresh.name}”'),
                subtitle: Text(_kind(fresh.kind)),
                onTap: () => Navigator.pop(context, fresh),
              ),
            for (final (i, cat) in existing.indexed)
              FadeSlideIn(
                index: i < 12 ? i : 12,
                child: ListTile(
                  leading: CategoryAvatar(cat, size: 36),
                  title: Text(cat.name),
                  subtitle: Text(
                    cat.archived
                        ? '${_kind(cat.kind)} · archived, will be restored'
                        : _kind(cat.kind),
                    style: TextStyle(color: c.muted),
                  ),
                  trailing: cat.id == group.target.id
                      ? Icon(Icons.check_rounded, color: c.lived)
                      : null,
                  onTap: () => Navigator.pop(context, cat),
                ),
              ),
          ],
        ),
      );
    },
  );
}

String _kind(CategoryKind kind) => switch (kind) {
  CategoryKind.spending => 'Spending',
  CategoryKind.investing => 'Investing',
  CategoryKind.income => 'Income',
};

/// Rows that couldn't be read, collapsed until tapped.
class ProblemsCard extends StatefulWidget {
  const ProblemsCard({super.key, required this.problems});

  final List<ImportProblem> problems;

  @override
  State<ProblemsCard> createState() => _ProblemsCardState();
}

class _ProblemsCardState extends State<ProblemsCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = widget.problems.length;
    return Material(
      color: c.warnSoft,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: c.warn, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$n ${n == 1 ? 'row' : 'rows'} couldn’t be read and will be skipped',
                      style: TextStyle(color: c.warn, fontWeight: FontWeight.w600),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: Motion.of(context, Motion.fast),
                    child: Icon(Icons.expand_more_rounded, color: c.warn),
                  ),
                ],
              ),
              AnimatedSize(
                duration: Motion.of(context, Motion.medium),
                curve: Motion.enter,
                alignment: Alignment.topCenter,
                child: !_open
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final p in widget.problems.take(30))
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${p.sheet}, row ${p.rowNumber}: ${p.reason}',
                                  style: TextStyle(color: c.ink2, fontSize: 13),
                                ),
                              ),
                            if (n > 30)
                              Text('…and ${n - 30} more', style: TextStyle(color: c.muted)),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One month in the preview: a bar that grows to its share of the biggest.
class MonthBar extends StatelessWidget {
  const MonthBar({super.key, required this.total, required this.max, required this.money});

  final MonthTotal total;
  final int max;
  final MoneyFormat money;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = DateFormat.yMMM().format(total.month.firstDay);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 74, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => Align(
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (total.cents.abs() / max).clamp(0.02, 1.0)),
                  duration: Motion.of(context, Motion.slow),
                  curve: Motion.enter,
                  builder: (context, t, _) => Container(
                    width: box.maxWidth * t,
                    height: 10,
                    decoration: BoxDecoration(
                      color: c.lived,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              '${total.count} · ${money.whole(total.cents)}',
              textAlign: TextAlign.right,
              style: TextStyle(color: c.muted, fontSize: 12.5, fontFeatures: tabularFigures),
            ),
          ),
        ],
      ),
    );
  }
}
