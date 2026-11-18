import '../entities/category.dart';

/// Contract for reading and writing categories.
///
/// The UI only depends on this interface; the implementation decides where
/// data lives (local database, remote backend, or both).
abstract interface class CategoryRepository {
  /// Emits every change. Archived categories are included only on request.
  Stream<List<Category>> watchAll({bool includeArchived = false});

  Future<List<Category>> getAll({bool includeArchived = true});

  /// Inserts or updates [category].
  Future<void> save(Category category);

  Future<void> setArchived(String id, {required bool archived});
}
