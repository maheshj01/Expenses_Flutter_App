import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/ids.dart';
import '../../domain/entities/category.dart';
import '../../shared/widgets/category_avatar.dart';

const categoryColors = <int>[
  0xFFE8F3E4,
  0xFFEDE9FB,
  0xFFFFF4D6,
  0xFFE3EEFB,
  0xFFE6F4F3,
  0xFFFBE7EE,
  0xFFF3E9FA,
  0xFFE4F1FA,
  0xFFFBEAEA,
  0xFFE7EBFF,
  0xFFFBF0DC,
  0xFFF1EEE8,
];

const _emojiChoices = [
  '🛒',
  '🍔',
  '☕',
  '🏠',
  '⚡',
  '💧',
  '🚗',
  '⛽',
  '🚌',
  '✈️',
  '📱',
  '💻',
  '🛍️',
  '👕',
  '🎬',
  '🎮',
  '🌿',
  '💊',
  '🏋️',
  '✂️',
  '🎁',
  '🐶',
  '👶',
  '🎓',
  '📚',
  '🧾',
  '🧻',
  '🔧',
  '💼',
  '📈',
  '🏦',
  '🪙',
  '❤️',
  '📦',
];

/// Add or edit a category. Returns the saved category.
Future<Category?> showCategoryEditor(BuildContext context, {Category? category}) {
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CategoryEditorSheet(category: category),
  );
}

class CategoryEditorSheet extends ConsumerStatefulWidget {
  const CategoryEditorSheet({super.key, this.category});

  final Category? category;

  @override
  ConsumerState<CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends ConsumerState<CategoryEditorSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.category?.name);
  final _otherIcon = TextEditingController();
  late String _emoji = widget.category?.emoji ?? '📦';
  late int _color = widget.category?.color ?? categoryColors.first;
  late CategoryKind _kind = widget.category?.kind ?? CategoryKind.spending;

  bool get _isEditing => widget.category != null;

  @override
  void dispose() {
    _name.dispose();
    _otherIcon.dispose();
    super.dispose();
  }

  Category get _draft => Category(
    id: widget.category?.id ?? newId(),
    name: _name.text.trim(),
    emoji: _emoji,
    color: _color,
    kind: _kind,
    sortOrder: widget.category?.sortOrder ?? 0,
    archived: widget.category?.archived ?? false,
  );

  /// Another category with the same name, ignoring case and spaces at the
  /// ends. Archived ones count too: restoring beats making a second one.
  Category? _duplicateIn(List<Category>? categories) {
    final name = _name.text.trim().toLowerCase();
    if (name.isEmpty) return null;
    return categories
        ?.where((c) => c.id != widget.category?.id && c.name.trim().toLowerCase() == name)
        .firstOrNull;
  }

  Future<void> _save() async {
    final category = _draft;
    if (category.name.isEmpty || _duplicateIn(ref.read(categoriesProvider).value) != null) return;
    await ref.read(categoryRepositoryProvider).save(category);
    if (mounted) Navigator.pop(context, category);
  }

  Future<void> _toggleArchive() async {
    final c = widget.category!;
    await ref.read(categoryRepositoryProvider).setArchived(c.id, archived: !c.archived);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Shown on the field as you type: a snack bar would sit behind this sheet.
    final duplicate = _duplicateIn(ref.watch(categoriesProvider).value);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEditing ? 'Edit category' : 'New category',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CategoryAvatar(_draft, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _name,
                    autofocus: !_isEditing,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Name, e.g. Groceries',
                      errorText: duplicate == null
                          ? null
                          : duplicate.archived
                          ? '“${duplicate.name}” already exists but is archived. Restore it instead.'
                          : '“${duplicate.name}” already exists',
                      errorMaxLines: 2,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<CategoryKind>(
              segments: const [
                ButtonSegment(value: CategoryKind.spending, label: Text('Spending')),
                ButtonSegment(value: CategoryKind.investing, label: Text('Saving')),
                ButtonSegment(value: CategoryKind.income, label: Text('Income')),
              ],
              selected: {_kind},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(switch (_kind) {
                CategoryKind.spending => 'Counts toward your spending and budget.',
                CategoryKind.investing => 'Savings or investments. Not counted as spending.',
                CategoryKind.income => 'Money coming in: salary, allowance, pension, gifts.',
              }, style: TextStyle(fontSize: 12, color: c.muted)),
            ),
            const SizedBox(height: 16),
            Text('Icon', style: TextStyle(color: c.muted, fontSize: 12.5)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final e in _emojiChoices)
                  _EmojiButton(e, e == _emoji, () {
                    _otherIcon.clear();
                    setState(() => _emoji = e);
                  }),
                SizedBox(
                  width: 92,
                  height: 40,
                  child: TextField(
                    key: const ValueKey('other-icon'),
                    controller: _otherIcon,
                    textAlign: TextAlign.center,
                    inputFormatters: [_OneCharacter()],
                    decoration: const InputDecoration(
                      hintText: 'Other',
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) {
                      if (v.isNotEmpty) setState(() => _emoji = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Color', style: TextStyle(color: c.muted, fontSize: 12.5)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in categoryColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = color),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c.categoryTile(color),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: color == _color ? c.ink : c.line,
                          width: color == _color ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _name.text.trim().isEmpty || duplicate != null ? null : _save,
              child: Text(_isEditing ? 'Save changes' : 'Add category'),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: _toggleArchive,
                child: Text(
                  widget.category!.archived ? 'Restore category' : 'Archive category',
                  style: TextStyle(color: widget.category!.archived ? c.lived : c.warn),
                ),
              ),
              if (!widget.category!.archived)
                Text(
                  'Archived categories are hidden when adding entries. Past entries keep it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  const _EmojiButton(this.emoji, this.selected, this.onTap);

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.sunk : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? c.ink : Colors.transparent),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

/// Keeps the icon field to one character, as people see it: an emoji made of
/// several code points (👩‍🍳, 🇮🇳) counts as one. A new one replaces the old.
class _OneCharacter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final characters = newValue.text.characters;
    if (characters.length <= 1) return newValue;
    // The character just typed: the one ending at the cursor, else the last.
    final end = newValue.selection.isValid ? newValue.selection.end : newValue.text.length;
    final typed = newValue.text.substring(0, end).characters.lastOrNull ?? characters.last;
    return TextEditingValue(
      text: typed,
      selection: TextSelection.collapsed(offset: typed.length),
    );
  }
}
