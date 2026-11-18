import '../../domain/entities/category.dart';

/// Starter categories, matching the expense sheet the app replaces.
///
/// They use fixed ids so two devices that both start fresh do not create
/// duplicates when they sync.
const defaultCategories = <Category>[
  Category(id: 'food', name: 'Food', emoji: '🛒', color: 0xFFE8F3E4, sortOrder: 0),
  Category(id: 'housing', name: 'Housing', emoji: '🏠', color: 0xFFEDE9FB, sortOrder: 1),
  Category(id: 'electricity', name: 'Electricity', emoji: '⚡', color: 0xFFFFF4D6, sortOrder: 2),
  Category(id: 'car', name: 'Car', emoji: '🚗', color: 0xFFE3EEFB, sortOrder: 3),
  Category(id: 'productivity', name: 'Productivity', emoji: '📱', color: 0xFFE6F4F3, sortOrder: 4),
  Category(id: 'shopping', name: 'Shopping', emoji: '🛍️', color: 0xFFFBE7EE, sortOrder: 5),
  Category(id: 'well_being', name: 'Well being', emoji: '🌿', color: 0xFFE9F6EA, sortOrder: 6),
  Category(
    id: 'entertainment',
    name: 'Entertainment',
    emoji: '🎬',
    color: 0xFFF3E9FA,
    sortOrder: 7,
  ),
  Category(id: 'travel', name: 'Travel', emoji: '✈️', color: 0xFFE4F1FA, sortOrder: 8),
  Category(id: 'medical', name: 'Medical', emoji: '💊', color: 0xFFFBEAEA, sortOrder: 9),
  Category(id: 'electronics', name: 'Electronics', emoji: '💻', color: 0xFFE6ECF5, sortOrder: 10),
  Category(id: 'misc', name: 'Misc', emoji: '📦', color: 0xFFF1EEE8, sortOrder: 11),
  Category(
    id: 'investment',
    name: 'Investment',
    emoji: '📈',
    color: 0xFFE7EBFF,
    kind: CategoryKind.investing,
    sortOrder: 12,
  ),
  Category(
    id: 'salary',
    name: 'Salary',
    emoji: '💼',
    color: 0xFFFBF0DC,
    kind: CategoryKind.income,
    sortOrder: 13,
  ),
];
