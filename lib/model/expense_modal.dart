import 'package:flutter/material.dart';

class ExpenseModal {
  int id;
  double amount;
  String description;
  double total;

  ExpenseModal(this.amount, this.description);

  set setAmount(double amount) => amount = amount;
  set expenseDescription(String desc) => description = desc;

  ExpenseModal.fromMap({@required Map<String, dynamic> map})
      : amount = map['amount'],
        description = map['description'],
        total = map['total'];
}
