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

const String currency = '₹';
const String expenseListTableName = 'expense';
const String expenseAmountColumn = 'amount';
const String expenseTypeColumn = 'type';
const String expenseTotalColumn = 'total';
