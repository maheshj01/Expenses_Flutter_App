import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/entities/category.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/category_avatar.dart';
import 'category_editor_sheet.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final all = ref.watch(categoriesProvider).value ?? const <Category>[];
    final active = all.where((c) => !c.archived).toList();
    final archived = all.where((c) => c.archived).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCategoryEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New category'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
        children: [
          for (final kind in CategoryKind.values)
            if (active.any((x) => x.kind == kind)) ...[
              SectionHeader(switch (kind) {
                CategoryKind.spending => 'Spending',
                CategoryKind.investing => 'Investing',
                CategoryKind.income => 'Income',
              }),
              _CategoryList(active.where((x) => x.kind == kind).toList()),
            ],
          if (archived.isNotEmpty) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => setState(() => _showArchived = !_showArchived),
              icon: Icon(_showArchived ? Icons.expand_less_rounded : Icons.expand_more_rounded),
              label: Text('Archived (${archived.length})', style: TextStyle(color: c.muted)),
            ),
            if (_showArchived) _CategoryList(archived),
          ],
        ],
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList(this.categories);

  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        children: [
          for (final (i, cat) in categories.indexed) ...[
            if (i > 0) const Divider(indent: 62),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: CategoryAvatar(cat),
              title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w500)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showCategoryEditor(context, category: cat),
            ),
          ],
        ],
      ),
    );
  }
}
