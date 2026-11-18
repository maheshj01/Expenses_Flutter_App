import '../repositories/category_repository.dart';
import '../repositories/entry_repository.dart';
import 'import_plan.dart';

/// What an import changed, so it can be undone.
class ImportResult {
  const ImportResult({
    required this.entryIds,
    required this.createdCategoryIds,
    required this.restoredCategoryIds,
  });

  final List<String> entryIds;
  final List<String> createdCategoryIds;
  final List<String> restoredCategoryIds;

  int get count => entryIds.length;
}

/// Saves an [ImportPlan] and can take it back.
class ImportRunner {
  ImportRunner(this._entries, this._categories);

  final EntryRepository _entries;
  final CategoryRepository _categories;

  Future<ImportResult> apply(ImportPlan plan) async {
    final created = plan.newCategories;
    for (final c in created) {
      await _categories.save(c);
    }
    final restored = plan.categoriesToRestore;
    for (final id in restored) {
      await _categories.setArchived(id, archived: false);
    }
    // Never overwrite an entry that is already there, e.g. one imported
    // before and edited since.
    final fresh = [
      for (final e in plan.entries)
        if (await _entries.byId(e.id) == null) e,
    ];
    await _entries.saveAll(fresh);
    return ImportResult(
      entryIds: [for (final e in fresh) e.id],
      createdCategoryIds: [for (final c in created) c.id],
      restoredCategoryIds: restored,
    );
  }

  /// Removes the imported entries and hides the categories it added.
  Future<void> undo(ImportResult result) async {
    await _entries.deleteAll(result.entryIds);
    for (final id in [...result.createdCategoryIds, ...result.restoredCategoryIds]) {
      await _categories.setArchived(id, archived: true);
    }
  }
}
