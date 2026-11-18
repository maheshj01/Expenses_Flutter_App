/// Which bucket money in a category belongs to.
///
/// Keeping investing separate from spending is a core idea of the app:
/// buying shares is building wealth, not living cost.
enum CategoryKind {
  spending,
  investing,
  income;

  static CategoryKind parse(String value) =>
      CategoryKind.values.firstWhere((k) => k.name == value, orElse: () => CategoryKind.spending);
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    this.kind = CategoryKind.spending,
    this.sortOrder = 0,
    this.archived = false,
  });

  final String id;
  final String name;
  final String emoji;

  /// ARGB color value, e.g. `0xFFE8F3E4`.
  final int color;
  final CategoryKind kind;
  final int sortOrder;

  /// Archived categories are hidden from pickers but keep their history.
  final bool archived;

  Category copyWith({
    String? name,
    String? emoji,
    int? color,
    CategoryKind? kind,
    int? sortOrder,
    bool? archived,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      kind: kind ?? this.kind,
      sortOrder: sortOrder ?? this.sortOrder,
      archived: archived ?? this.archived,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Category &&
      other.id == id &&
      other.name == name &&
      other.emoji == emoji &&
      other.color == color &&
      other.kind == kind &&
      other.sortOrder == sortOrder &&
      other.archived == archived;

  @override
  int get hashCode => Object.hash(id, name, emoji, color, kind, sortOrder, archived);

  @override
  String toString() => 'Category($name, ${kind.name})';
}
