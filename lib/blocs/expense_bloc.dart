import 'dart:async';
import 'package:expense_manager/model/expense_modal.dart';
import 'package:rxdart/rxdart.dart';

class ExpenseBloc {
  final totalExpenseController = BehaviorSubject<double>();
  final expenseListController = BehaviorSubject<List<ExpenseModal>>();

  Stream<List<ExpenseModal>> get expenseListStream =>
      expenseListController.stream;
  StreamSink<List<ExpenseModal>> get expenseListStreamSink =>
      expenseListController.sink;
  Stream<double> get totalExpenseStream => totalExpenseController.stream;
  StreamSink<double> get totalExpenseStreamSink => totalExpenseController.sink;

  ExpenseBloc() {
    totalExpenseController.stream.listen(_updateTotalExpense);
    expenseListController.stream.listen(_addToExpense);
  }

  void _updateTotalExpense(double total) {
    totalExpenseStreamSink.add(total);
  }

  void _addToExpense(List<ExpenseModal> event) {}
}
