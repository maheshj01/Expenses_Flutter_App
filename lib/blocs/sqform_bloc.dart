import 'dart:async';

import 'package:expense_manager/model/model.dart';
import 'package:rxdart/rxdart.dart';

class SqfOrmBloc {
  final totalExpenseController = BehaviorSubject<double>();
  final expenseListController = BehaviorSubject<List<Expense>>();
  final expenseModalController = BehaviorSubject<Expense>();
  List<Expense> expenseList = [];
  double totalExpense = 0.0;
  Stream<List<Expense>> get expenseListStream => expenseListController.stream;
  StreamSink<List<Expense>?> get expenseListStreamSink =>
      expenseListController.sink;
  Stream<double> get totalExpenseStream => totalExpenseController.stream;
  StreamSink<double> get totalExpenseStreamSink => totalExpenseController.sink;

  SqfOrmBloc() {
    // TODO : LOAD THE LIST WHEN THE APP STARTS
    loadTheExpenses();
    expenseModalController.stream
        .listen((model) => this.updateTotalExpense(model));
    // expenseListController.stream.listen((onData) => this.loadTheExpenses());
  }

  void loadTheExpenses() async {
    try {
      expenseList = await Expense().select().toList();
      if (expenseList.length > 0) {
        print("fetched the list");
        totalExpenseStreamSink.add(expenseList[expenseList.length - 1].total!);
      } else {
        // either no items in List or firstTime fetching the empty list
        print("no items in list");
        totalExpenseStreamSink.add(0.00);
        print("result length = " + expenseList.length.toString());
      }
      expenseListStreamSink.add(expenseList);
    } catch (error) {
      print("error fetching expenses=>" + error.toString());
    }
  }

  void updateTotalExpense(Expense modal) {
    //TODO:query to update the total Expenses
    expenseList.insert(0, modal);
    expenseListStreamSink.add(expenseList);
    totalExpense = totalExpenseController.value + modal.amount!;
    print("total Expense:" + totalExpense.toString());
    print("length =" + expenseList.length.toString());
    totalExpenseStreamSink.add(totalExpense);
    insertDb(modal, totalExpense);
  }

  void insertDb(Expense model, double total) async {
    // TODO: query to insert a new Expense into Database
    final expense = Expense(
        amount: model.amount,
        description: model.description,
        total: total,
        datetime: model.datetime ?? DateTime.now(),
        type: model.type!,
        isDeleted: false);
    await expense.save();
    if (expense.saveResult!.success)
      print(expense.saveResult.toString());
    else
      print("failed to save to database ${expense.saveResult!.errorMessage}");
    // await Expense.withFields(model.amount, model.description, total, false)
    //     .save()
    //     .then((id) {
    //   print("doc with id " + id.toString() + " saved");
    // }).catchError((error) {
    //   print("error inserting into database:" + error.toString());
    // });
    await Expense().select().toList().then((expenseList) {
      print("length = " + expenseList.length.toString());
      print("total = " + expenseList[expenseList.length - 1].total.toString());
    });
  }

  void removeExpenseItem(Expense removeModel) async {
    var result = Expense().select().id.equals(removeModel.id).delete();
    loadTheExpenses();
  }

  void dispose() {
    totalExpenseController.close();
    expenseListController.close();
    expenseModalController.close();
  }
}
