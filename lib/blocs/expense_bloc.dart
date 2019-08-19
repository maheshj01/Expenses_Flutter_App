import 'dart:async';
import 'package:expense_manager/db/db_config.dart';
import 'package:expense_manager/model/expense_modal.dart';
import 'package:rxdart/rxdart.dart';

class ExpenseBloc {
  final totalExpenseController = BehaviorSubject<double>();
  final expenseListController = BehaviorSubject<List<ExpenseModal>>();
  final dbObject = DatabaseConfig.instance;

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
    dbObject.queryAllRows().then((result) {
      result.length > 0
          ? {
              print("data fetched"),
              result.forEach((row) {
                expenseList.add(ExpenseModal.fromMap(map: row));
                totalExpenseStreamSink.add(row['total']);
                print(row['total']);
              }),
              expenseListStreamSink.add(expenseList),
              print("added list to streams")
            }
          : {
              totalExpenseStreamSink.add(0.00),
              print("result length = " + result.length.toString())
            };
    }).catchError((e) {
      print("error: " + e.toString());
    });
  }

  void updateTotalExpense(ExpenseModal modal) {
    expenseList.insert(0, modal);
    expenseListStreamSink.add(expenseList);
    totalExpense = totalExpenseController.value + modal.amount;
    print("total Expense:" + totalExpense.toString());
    totalExpenseStreamSink.add(totalExpense);
    insertDb(modal, totalExpense);
  }

  void insertDb(ExpenseModal modal, double total) {
    Map<String, dynamic> row = {
      DatabaseConfig.columnAmount: modal.amount,
      DatabaseConfig.columnDescription: modal.description,
      DatabaseConfig.columnTotal: total
    };
    dbObject.insert(row).then((data) {
      print("inserted Successfully" + data.toString());
    }).catchError((e) {
      print("insert failed due to" + e);
    });
  }
  // void _addToExpense(List<ExpenseModal> event) {}

  void dispose() {
    totalExpenseController.close();
    expenseListController.close();
  }
}
