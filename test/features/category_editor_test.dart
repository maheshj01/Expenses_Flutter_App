import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_bucks/app/providers.dart';
import 'package:three_bucks/app/theme.dart';
import 'package:three_bucks/domain/entities/category.dart';
import 'package:three_bucks/features/categories/category_editor_sheet.dart';

void main() {
  const food = Category(id: 'food', name: 'Food', emoji: '🍔', color: 1);
  const gym = Category(id: 'gym', name: 'Gym', emoji: '🏋️', color: 1, archived: true);

  Future<void> openEditor(WidgetTester tester, {Category? editing}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) => Stream.value([food, gym])),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(body: CategoryEditorSheet(category: editing)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  FilledButton saveButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  testWidgets('a name that already exists is flagged on the field', (tester) async {
    await openEditor(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Name, e.g. Groceries'), '  food ');
    await tester.pump();
    expect(find.text('“Food” already exists'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Name, e.g. Groceries'), 'Fuel');
    await tester.pump();
    expect(find.textContaining('already exists'), findsNothing);
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('an archived category with that name says to restore it', (tester) async {
    await openEditor(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Name, e.g. Groceries'), 'gym');
    await tester.pump();
    expect(find.text('“Gym” already exists but is archived. Restore it instead.'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('the other icon field holds one character', (tester) async {
    await openEditor(tester);
    final field = find.byKey(const ValueKey('other-icon'));
    String text() => tester.widget<TextField>(field).controller!.text;

    await tester.enterText(field, '🍕');
    await tester.pump();
    expect(text(), '🍕');

    // Typing more keeps only the newest character.
    await tester.enterText(field, '🍕ab');
    await tester.pump();
    expect(text(), 'b');

    // An emoji made of several code points still counts as one.
    await tester.enterText(field, '👩‍🍳');
    await tester.pump();
    expect(text(), '👩‍🍳');
  });

  testWidgets('editing a category may keep its own name', (tester) async {
    await openEditor(tester, editing: food);

    expect(find.textContaining('already exists'), findsNothing);
    expect(saveButton(tester).onPressed, isNotNull);
  });
}
