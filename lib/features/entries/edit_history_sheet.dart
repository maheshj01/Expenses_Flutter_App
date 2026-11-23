import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/day.dart';
import '../../domain/history/edit.dart';
import '../../shared/money_format.dart';
import '../../shared/widgets/app_card.dart';

/// "Edited 3 times · See changes", or nothing before the first edit.
class EditHistoryLink extends StatelessWidget {
  const EditHistoryLink({super.key, required this.edits, required this.onTap});

  final List<Edit> edits;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (edits.isEmpty) return const SizedBox.shrink();
    final n = edits.length;
    return Align(
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: context.colors.muted),
        icon: const Icon(Icons.history_rounded, size: 18),
        label: Text('Edited ${n == 1 ? 'once' : '$n times'} · See changes'),
      ),
    );
  }
}

/// Every edit of an entry or bill, newest first, each with what changed.
///
/// [nameOf] names whoever made an edit (shared bills); [created] is the
/// line shown last, e.g. "Created Nov 20 by Sam".
Future<void> showEditHistorySheet(
  BuildContext context, {
  required List<Edit> edits,
  required String currencyCode,
  required String created,
  String Function(String uid)? nameOf,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _EditHistorySheet(
      edits: edits,
      currencyCode: currencyCode,
      created: created,
      nameOf: nameOf,
    ),
  );
}

class _EditHistorySheet extends ConsumerWidget {
  const _EditHistorySheet({
    required this.edits,
    required this.currencyCode,
    required this.created,
    this.nameOf,
  });

  final List<Edit> edits;
  final String currencyCode;
  final String created;
  final String Function(String uid)? nameOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final categories = ref.watch(categoryMapProvider);
    final describe = EditDescriber(
      currencyCode: currencyCode,
      categoryName: (id) => categories[id]?.name,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('History', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final edit in edits) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${DateFormat.yMMMd().add_jm().format(edit.at)}'
                    '${edit.by != null && nameOf != null ? ' · ${nameOf!(edit.by!)}' : ''}',
                    style: TextStyle(color: c.muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 6),
                  for (final line in describe.lines(edit.changes))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 96,
                            child: Text(line.label, style: TextStyle(color: c.ink2, fontSize: 14)),
                          ),
                          Expanded(
                            child: Text(
                              line.text,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Text(created, style: TextStyle(color: c.muted, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Turns recorded changes into readable lines, e.g. "Amount: $40.00 → $46.00".
class EditDescriber {
  const EditDescriber({required this.currencyCode, required this.categoryName});

  /// The currency amounts are in now; an edit that changed the currency
  /// shows the old amount in the old currency.
  final String currencyCode;
  final String? Function(String id) categoryName;

  static const _labels = {
    EditField.amount: 'Amount',
    EditField.currency: 'Currency',
    EditField.category: 'Category',
    EditField.date: 'Date',
    EditField.note: 'Note',
    EditField.memo: 'Message',
    EditField.people: 'People',
    EditField.guests: 'Not on app',
    EditField.guestNames: 'Their names',
    EditField.split: 'Split',
    EditField.deleted: 'Status',
  };

  List<({String label, String text})> lines(Map<EditField, FieldChange> changes) {
    final currency = changes[EditField.currency];
    final fromCurrency = currency?.from as String? ?? currencyCode;
    final toCurrency = currency?.to as String? ?? currencyCode;
    String value(EditField field, Object? v, {required bool before}) => switch (field) {
      EditField.amount when v is int => MoneyFormat(before ? fromCurrency : toCurrency)(v),
      EditField.category when v is String => categoryName(v) ?? v,
      EditField.date when v is int => DateFormat.yMMMd().format(DayKey.toDate(v)),
      EditField.note || EditField.memo => (v as String?)?.isNotEmpty ?? false ? '“$v”' : 'none',
      EditField.people || EditField.guestNames => v is List && v.isNotEmpty ? v.join(', ') : 'none',
      EditField.split when v is int => v <= 1 ? 'not split' : '$v ways',
      _ => '$v',
    };
    return [
      for (final field in EditField.values)
        if (changes[field] case final change?)
          (
            label: _labels[field]!,
            text: field == EditField.deleted
                ? (change.to == true ? 'Deleted' : 'Restored')
                : '${value(field, change.from, before: true)} → ${value(field, change.to, before: false)}',
          ),
    ];
  }
}
