import 'dart:async';

import 'package:expense_manager/model/model.dart';
import 'package:rxdart/rxdart.dart';

class ExpenseBloc {
  final totalExpenseController = BehaviorSubject<double>();
  final _expenseListController = BehaviorSubject<List<Expense>>();
  final _expenseModalController = BehaviorSubject<Expense>();
  final _labelBloc = BehaviorSubject<List<String>>();
  List<Expense> expenseList = [];
  double totalExpense = 0.0;

  Stream<List<Expense>> get expenseListStream => _expenseListController.stream;
  StreamSink<List<Expense>?> get expenseListStreamSink =>
      _expenseListController.sink;
  Stream<Expense> get expenseModelStream => _expenseModalController.stream;
  StreamSink<Expense> get expenseModelStreamSink =>
      _expenseModalController.sink;

  Stream<double> get totalExpenseStream => totalExpenseController.stream;
  StreamSink<double> get totalExpenseStreamSink => totalExpenseController.sink;

  Stream<List<String>> get labelStream => _labelBloc.stream;
  StreamSink<List<String>> get labelStreamSink => _labelBloc.sink;

  ExpenseBloc() {
    loadTheExpenses();
    _expenseModalController.stream
        .listen((model) => this.updateTotalExpense(model));
  }

  void loadTheExpenses({List<Expense>? expenses}) async {
    List<String> labels = [];
    try {
      expenseList = expenses ?? await Expense().select().toList();
      if (expenseList.length > 0) {
        totalExpenseStreamSink.add(expenseList[expenseList.length - 1].total!);
        expenseList.forEach((element) {
          print(element.label);

          /// label is a commas separated string
          if (element.label!.isNotEmpty) {
            final expenseLabels = element.label!.split(',').toList();
            expenseLabels.forEach((label) {
              if (!labels.contains(label)) {
                labels.add(label);
              }
            });
          }
        });

        /// loading expenses without filters
        if (expenses == null) {
          updateLabels(labels);
        }
      } else {
        // either no items in List or firstTime fetching the empty list
        totalExpenseStreamSink.add(0.00);
        print("result length = " + expenseList.length.toString());
      }
      expenseListStreamSink.add(expenseList);
    } catch (error) {
      print("error fetching expenses=>" + error.toString());
    }
  }

  Future<List<Expense>> getExpenses() async {
    try {
      final expenses = await Expense().select().toList();
      return expenses;
    } catch (_) {
      print('Exception occured $_');
      return [];
    }
  }

  Future<void> updateLabels(List<String> newLabels) async {
    labelStreamSink.add(newLabels);
  }

  Future<void> updateTotalExpense(Expense modal) async {
    totalExpense = totalExpenseController.value + modal.amount!;
    totalExpenseStreamSink.add(totalExpense);
    await insertDb(modal, totalExpense);
    loadTheExpenses();
  }

  Future<void> insertDb(Expense model, double total) async {
    // TODO: query to insert a new Expense into Database
    final expense = Expense(
        amount: model.amount,
        description: model.description,
        total: total,
        datetime: model.datetime ?? DateTime.now(),
        type: model.type!,
        label: model.label,
        isDeleted: false);
    await expense.save();
    if (expense.saveResult!.success)
      print(expense.saveResult.toString());
    else
      print("failed to save to database ${expense.saveResult!.errorMessage}");
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
    _expenseListController.close();
    _expenseModalController.close();
    _labelBloc.close();
  }
}
