import 'dart:async';
import 'package:expense_manager/model/expense_modal.dart';
import 'package:rxdart/rxdart.dart';

class ExpenseBloc {
  final totalExpenseController = BehaviorSubject<double>();
  final expenseListController = BehaviorSubject<List<ExpenseModal>>();
  List<ExpenseModal> expenseList = [];
  double totalExpense;
  Stream<List<ExpenseModal>> get expenseListStream =>
      expenseListController.stream;
  StreamSink<List<ExpenseModal>> get expenseListStreamSink =>
      expenseListController.sink;
  Stream<double> get totalExpenseStream => totalExpenseController.stream;
  StreamSink<double> get totalExpenseStreamSink => totalExpenseController.sink;

  ExpenseBloc() {
    print("called bloc");
    totalExpenseStreamSink.add(0.00);
  }

  void updateTotalExpense(ExpenseModal modal) {
    totalExpense = totalExpenseController.value + modal.amount;
    totalExpenseStreamSink.add(totalExpense);
  }

  // void _addToExpense(List<ExpenseModal> event) {}

  void dispose() {
    totalExpenseController.close();
    expenseListController.close();
  }
}
