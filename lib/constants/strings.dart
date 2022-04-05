import 'package:flutter/material.dart';

const pages = ["LoginPage", "ExpensePage"];

OutlineInputBorder inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: Colors.black38));

const emptyListMessage = [
  'Nothing here yet😋\nAre you shopping ?',
  'Nothing here yet😋\nYou are having a great Day',
  "Nothing here yet😋\nIt seems You are Good at Managing your Wallet",
  "Nothing here yet😋\nIts a Lovely day to Spend !"
];

const String rupeeSymbol = '₹';
const String expenseListTableName = 'expense';
const String expenseAmountColumn = 'amount';
const String expenseTypeColumn = 'type';
const String expenseTotalColumn = 'total';