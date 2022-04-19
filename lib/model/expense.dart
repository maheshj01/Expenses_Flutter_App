import 'package:expense_manager/constants/strings.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';
part 'expense.freezed.dart';
part 'expense.g.dart';

@freezed
class Expense with _$Expense {
  const Expense._();
  factory Expense(
      {@Default(0.0) double amount,
      @Default('') String description,
      @Default(SpendType.once) SpendType type,
      DateTime? dateTime,
      @Default([]) List<String> labels}) = _Expense;

  factory Expense.fromJson(Map<String, dynamic> json) =>
      _$ExpenseFromJson(json);
}
