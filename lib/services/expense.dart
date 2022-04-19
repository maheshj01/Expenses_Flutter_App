import 'dart:async';

import 'package:expense_manager/model/expense.dart';
import 'package:expense_manager/services/database/database_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseService {
  final totalExpenseController = BehaviorSubject<double>();
  final _expenseListController = BehaviorSubject<List<Expense>>();
  final _expenseModalController = BehaviorSubject<Expense>();
  final _labelBloc = BehaviorSubject<List<String>>();

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
  ExpenseService() {
    loadTheExpenses();
    _expenseModalController.stream
        .listen((model) => this.onExpenseAdded(model));
  }

  /// loads the specified list of expenses
  /// if the list is null then it loads all the expenses from the database
  /// This is also updates the total expense for the list
  void loadTheExpenses({List<Expense>? filteredList}) async {
    List<String> labels = [];
    List<Expense> expenseList = [];
    try {
      expenseList = filteredList ?? await getExpenses();
      if (expenseList.length > 0) {
        expenseList.forEach((element) {
          /// label is a commas separated string
          if (element.labels.isNotEmpty) {
            final expenseLabels = element.labels;
            expenseLabels.forEach((label) {
              if (!labels.contains(label)) {
                labels.add(label);
              }
            });
          }
        });

        /// loading expenses without filters
        if (filteredList == null) {
          updateLabels(labels);
        }
      } else {
        // either no items in List or firstTime fetching the empty list
        totalExpenseStreamSink.add(0.00);
        print("result length = " + expenseList.length.toString());
      }
      expenseListStreamSink.add(expenseList);
      updateTotalFromList(expenses: expenseList);
    } catch (error) {
      print("error fetching expenses=>" + error.toString());
    }
    FirebaseFirestore.instance
        .collection('users')
        .doc('elon@spacex.com')
        .collection('expenses')
        .get()
        .then((QuerySnapshot value) {
      if (value.docs.length > 0) {
        value.docs.forEach((doc) {
          print(doc["amount"]);
        });
      } else {
        print('Document does not exist on the database');
      }
    });
  }

  Future<List<Expense>> getExpenses() async {
    try {
      final expenses = await DataBaseService.getExpenses();
      return expenses;
    } catch (_) {
      print('Exception occured $_');
      return [];
    }
  }

  Future<void> updateTotalFromList({List<Expense>? expenses}) async {
    if (expenses == null) {
      expenses = await getExpenses();
    }
    double totalExpenses = 0.0;
    expenses.forEach((element) {
      totalExpenses += element.amount;
    });
    totalExpenseStreamSink.add(totalExpenses);
  }

  Future<void> updateLabels(List<String> newLabels) async {
    labelStreamSink.add(newLabels);
  }

  Future<void> onExpenseAdded(Expense modal) async {
    final lastExpense = await getLastExpenseFromDb();
    final lastAmount = lastExpense == null ? 0.0 : lastExpense.amount;
    final totalExpense = lastAmount + modal.amount;
    totalExpenseStreamSink.add(totalExpense);
    await insertDb(modal, totalExpense);
    loadTheExpenses();
  }

  Future<Expense?> getLastExpenseFromDb() async {
    try {
      final expenseListInDesc = DataBaseService.getLastExpense();
      return expenseListInDesc;
    } catch (_) {
      print('Exception occured $_');
      return null;
    }
  }

  Future<void> insertDb(Expense model, double total) async {
    // TODO: query to insert a new Expense into Database
    try {
      final id = await DataBaseService.insertExpense(model);
      print('Expense inserted with id $id');
    } catch (_) {
      print('Exception occured $_');
    }
  }

  void removeExpenseItem(String docId) async {
    await DataBaseService.removeExpense(docId);
  }

  void dispose() {
    totalExpenseController.close();
    _expenseListController.close();
    _expenseModalController.close();
    _labelBloc.close();
  }
}
