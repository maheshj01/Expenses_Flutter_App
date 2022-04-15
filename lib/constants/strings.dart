import 'package:expense_manager/model/spend.dart';
import 'package:flutter/material.dart';

const pages = ["LoginPage", "ExpensePage", "HomePage", "SettingsPage"];

const logoPath = 'assets/images/expender.png';
const assetDirectory = 'assets/';
const imagesDirectory = 'assets/images';

OutlineInputBorder inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: Colors.black38, width: 0.5));

const emptyListMessage = [
  'Nothing here yet😋\nAre you shopping ?',
  'Nothing here yet😋\nYou are having a great Day',
  "Nothing here yet😋\nIt seems You are Good at Managing your Wallet",
  "Nothing here yet😋\nIts a Lovely day to Spend !"
];

const String dateFormatter = 'MMMM dd, y';

List<SpendType> expenseTypes = [
  SpendType.once,
  SpendType.weekly,
  SpendType.monthly
];

const String rupeeSymbol = '₹';
const String expenseListTableName = 'expense';
const String expenseAmountColumn = 'amount';
const String expenseTypeColumn = 'type';
const String expenseTotalColumn = 'total';

List<Currency> currencyList = [
  Currency(code: 'INR', name: 'Indian Rupee', symbol: '₹'),
  Currency(code: 'USD', name: 'US Dollar', symbol: '\$'),
  Currency(code: 'EUR', name: 'Euro', symbol: '€'),
  Currency(code: 'GBP', name: 'British Pound', symbol: '£'),
  Currency(code: 'JPY', name: 'Japanese Yen', symbol: '¥'),
  Currency(code: 'AFN', name: 'Afghan Afghani', symbol: '؋'),
  Currency(code: 'AUD', name: 'Australian Dollar', symbol: 'AUD'),
  Currency(code: 'NZD', name: 'New Zealand Dollar', symbol: 'NZD'),
  Currency(code: 'CHF', name: 'Swiss Franc', symbol: 'CHF'),
  Currency(code: 'HKD', name: 'Hong Kong Dollar', symbol: 'HKD'),
  Currency(code: 'SGD', name: 'Singapore Dollar', symbol: 'SGD'),
  Currency(code: 'SEK', name: 'Swedish Krona', symbol: 'SEK'),
  Currency(code: 'DKK', name: 'Danish Krone', symbol: 'DKK'),
  Currency(code: 'NOK', name: 'Norwegian Krone', symbol: 'NOK'),
  Currency(code: 'KRW', name: 'South Korean Won', symbol: '₩'),
  Currency(code: 'TRY', name: 'Turkish Lira', symbol: 'TRY'),
  Currency(code: 'RUB', name: 'Russian Ruble', symbol: 'RUB'),
  Currency(code: 'MXN', name: 'Mexican Peso', symbol: 'MXN'),
  Currency(code: 'BRL', name: 'Brazilian Real', symbol: 'BRL'),
  Currency(code: 'CAD', name: 'Canadian Dollar', symbol: 'CAD'),
  Currency(code: 'MYR', name: 'Malaysian Ringgit', symbol: 'MYR'),
  Currency(code: 'PHP', name: 'Philippine Peso', symbol: 'PHP'),
  Currency(code: 'IDR', name: 'Indonesian Rupiah', symbol: 'IDR'),
  Currency(code: 'THB', name: 'Thai Baht', symbol: 'THB'),
  Currency(code: 'VND', name: 'Vietnamese Dong', symbol: 'VND'),
  Currency(code: 'CNY', name: 'Chinese Yuan', symbol: 'CNY'),
  Currency(code: 'ILS', name: 'Israeli New Sheqel', symbol: 'ILS'),
  Currency(code: 'BGN', name: 'Bulgarian Lev', symbol: 'BGN'),
  Currency(code: 'HRK', name: 'Croatian Kuna', symbol: 'HRK'),
  Currency(code: 'CZK', name: 'Czech Koruna', symbol: 'CZK'),
  Currency(code: 'HUF', name: 'Hungarian Forint', symbol: 'HUF'),
  Currency(code: 'RON', name: 'Romanian Leu', symbol: 'RON'),
  Currency(code: 'NGN', name: 'Nigerian Naira', symbol: 'NGN'),
  Currency(code: 'LTL', name: 'Lithuanian Litas', symbol: 'LTL'),
  Currency(code: 'LVL', name: 'Latvian Lats', symbol: 'LVL'),
  Currency(code: 'ZAR', name: 'South African Rand', symbol: 'ZAR'),
  Currency(code: 'QAR', name: 'Qatari Riyal', symbol: 'QAR'),
  Currency(code: 'XOF', name: 'CFA Franc BCEAO', symbol: 'XOF'),
  Currency(code: 'XAF', name: 'CFA Franc BEAC', symbol: 'XAF'),
  Currency(code: 'XCD', name: 'East Caribbean Dollar', symbol: 'XCD'),
  Currency(code: 'XDR', name: 'SDR (Special Drawing Right)', symbol: 'XDR'),
];

class Currency {
  final String name;
  final String symbol;
  final String code;

  Currency({required this.name, required this.symbol, required this.code});
}
