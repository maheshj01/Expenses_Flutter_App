import 'package:flutter_test/flutter_test.dart';
import 'package:three_bucks/domain/entities/ledger_entry.dart';
import 'package:three_bucks/domain/services/quick_entry_parser.dart';

void main() {
  group('QuickEntryParser', () {
    test('reads amount and note', () {
      final r = QuickEntryParser.parse('kroger 18');
      expect(r.amountCents, 1800);
      expect(r.note, 'Kroger');
      expect(r.splitWays, 1);
      expect(r.moneyBack, isFalse);
    });

    test('reads decimals, dollar sign and split', () {
      final r = QuickEntryParser.parse(r'costco $46.50 split');
      expect(r.amountCents, 4650);
      expect(r.note, 'Costco');
      expect(r.splitWays, 2);
    });

    test('reads n-way split', () {
      expect(QuickEntryParser.parse('wifi 40 split 3').splitWays, 3);
      expect(QuickEntryParser.parse('wifi 40 /3').splitWays, 3);
    });

    test('detects money back', () {
      final r = QuickEntryParser.parse('rent share back 500');
      expect(r.moneyBack, isTrue);
      expect(r.amountCents, 50000);
      expect(QuickEntryParser.parse('+500 rent').moneyBack, isTrue);
    });

    test('keeps numbers that are part of words in the note', () {
      final r = QuickEntryParser.parse('nvda x2 391.84');
      expect(r.amountCents, 39184);
      expect(r.note, 'Nvda x2');
    });

    test('empty input', () {
      expect(QuickEntryParser.parse('  ').amountCents, isNull);
    });
  });

  group('QuickEntryParser with saved names', () {
    const known = ['Sam', 'Ana Ruiz', 'Lee'];

    test('takes names after a split and counts them', () {
      final r = QuickEntryParser.parse('pizza 30 split with sam and ana ruiz', knownNames: known);
      expect(r.guestNames, ['Sam', 'Ana Ruiz']);
      expect(r.splitWays, 3);
      expect(r.note, 'Pizza');
      expect(r.amountCents, 3000);
    });

    test('keeps a larger split count', () {
      final r = QuickEntryParser.parse('rent 1800 split 4 sam', knownNames: known);
      expect(r.splitWays, 4);
      expect(r.guestNames, ['Sam']);
    });

    test('ignores names without a split', () {
      final r = QuickEntryParser.parse('dinner with sam 40', knownNames: known);
      expect(r.splitWays, 1);
      expect(r.guestNames, isEmpty);
      expect(r.note, 'Dinner with sam');
    });

    test('matches whole words only', () {
      final r = QuickEntryParser.parse('sleep aid 12 split', knownNames: known);
      expect(r.guestNames, isEmpty);
      expect(r.note, 'Sleep aid');
    });
  });

  group('CategorySuggester', () {
    LedgerEntry e(String note, String cat) =>
        LedgerEntry(id: note, amountCents: 100, categoryId: cat, date: DateTime(2026), note: note);

    final suggester = CategorySuggester([
      e('Kroger', 'food'),
      e('kroger and costco', 'food'),
      e('Costco gas', 'car'),
      e('Costco', 'food'),
      e('Shell gas', 'car'),
    ]);

    test('suggests the most used category for a word', () {
      final s = suggester.suggest('kroger 18');
      expect(s?.categoryId, 'food');
      expect(s?.timesUsed, 2);
      expect(suggester.suggest('gas 40')?.categoryId, 'car');
      expect(suggester.suggest('costco')?.categoryId, 'food');
    });

    test('returns null for unknown words', () {
      expect(suggester.suggest('dentist 90'), isNull);
    });

    test('respects allowed ids', () {
      expect(suggester.suggest('costco', allowedIds: {'car'})?.categoryId, 'car');
    });
  });
}
