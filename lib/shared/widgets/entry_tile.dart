import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/social_providers.dart';
import '../../app/theme.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/ledger_entry.dart';
import 'category_avatar.dart';

class EntryTile extends ConsumerWidget {
  const EntryTile(this.entry, {super.key, this.onTap, this.showDate = true});

  final LedgerEntry entry;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final money = ref.watch(moneyFormatProvider);
    final category = ref.watch(categoryMapProvider)[entry.categoryId];
    final bill = entry.billId == null ? null : ref.watch(billMapProvider)[entry.billId];
    final me = ref.watch(accountProvider.select((a) => a.value?.uid));
    final kind = category?.kind ?? CategoryKind.spending;
    final amountColor = entry.isMoneyBack
        ? c.lived
        : switch (kind) {
            CategoryKind.investing => c.invested,
            CategoryKind.income => c.earned,
            CategoryKind.spending => c.ink,
          };
    final title = entry.note.isEmpty ? (category?.name ?? 'Uncategorised') : entry.note;
    final others = bill == null
        ? const <String>[]
        : [
            for (final uid in bill.members)
              if (uid != me) bill.nameOf(uid).split(' ').first,
          ];
    final subtitle = [
      category?.name ?? 'Uncategorised',
      if (showDate) DateFormat.MMMd().format(entry.date),
      if (others.isNotEmpty) 'with ${others.join(', ')}',
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CategoryAvatar(category),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: c.muted),
                        ),
                      ),
                      if (entry.isSplit) ...[
                        const SizedBox(width: 6),
                        _Tag(_splitLabel(entry.splitWays)),
                      ],
                      if (bill != null && bill.isDisputed) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.flag_rounded, size: 14, color: c.warn),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  money.signed(entry.shareCents),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                    fontFeatures: tabularFigures,
                  ),
                ),
                if (entry.isSplit)
                  Text(
                    'of ${money(entry.amountCents.abs())}',
                    style: TextStyle(fontSize: 11.5, color: c.muted, fontFeatures: tabularFigures),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _splitLabel(int ways) => switch (ways) {
  2 => '½',
  3 => '⅓',
  4 => '¼',
  _ => '1/$ways',
};

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: c.livedSoft, borderRadius: BorderRadius.circular(6)),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.lived),
      ),
    );
  }
}
