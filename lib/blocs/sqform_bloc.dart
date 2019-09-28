import 'dart:async';

import 'package:expense_manager/model/model.dart';
import 'package:rxdart/rxdart.dart';

class SqfOrmBloc {
  final totalExpenseController = BehaviorSubject<double>();
  final expenseListController = BehaviorSubject<List<Expense>>();

  List<Expense> expenseList = [];
  double totalExpense;
  Stream<List<Expense>> get expenseListStream => expenseListController.stream;
  StreamSink<List<Expense>> get expenseListStreamSink =>
      expenseListController.sink;
  Stream<double> get totalExpenseStream => totalExpenseController.stream;
  StreamSink<double> get totalExpenseStreamSink => totalExpenseController.sink;

  SqfOrmBloc() {
    // TODO : LOAD THE LIST WHEN THE APP STARTS
    loadTheExpenses();
  }

  void loadTheExpenses() async {
    try {
      expenseList = await Expense().select().toList();
      if (expenseList.length > 0) {
        print("fetched the list");
        expenseListStreamSink.add(expenseList);
        totalExpenseStreamSink.add(expenseList[expenseList.length - 1].total);
      } else {
        // either no items in List or firstTime fetching the empty list
        print("no items in list");
        totalExpenseStreamSink.add(0.00);
        print("result length = " + expenseList.length.toString());
      }
    } catch (error) {
      print("error fetching the expenses=>" + error);
    }
  }

  void updateTotalExpense(Expense modal) {
    //TODO:query to update the total Expenses
    expenseList.insert(0, modal);
    expenseListStreamSink.add(expenseList);
    totalExpense = totalExpenseController.value + modal.amount;
    print("total Expense:" + totalExpense.toString());
    print("length =" + expenseList.length.toString());
    totalExpenseStreamSink.add(totalExpense);
    insertDb(modal, totalExpense);
  }

  void insertDb(Expense model, double total) async {
    // TODO: query to insert a new Expense into Database
    await Expense.withFields(model.amount, model.description, total, false)
        .save()
        .then((id) {
      print("doc with id " + id.toString() + " saved");
    }).catchError((error) {
      print("error inserting into database:" + error.toString());
    });
    await Expense().select().toList().then((expenseList) {
      print("length = " + expenseList.length.toString());
      print("total = " + expenseList[expenseList.length - 1].total.toString());
    });
  }

  void dispose() {
    totalExpenseController.close();
    expenseListController.close();
  }
}
