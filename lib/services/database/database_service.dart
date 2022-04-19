import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_manager/model/expense.dart';

class DataBaseService {
  static final DataBaseService _singleton = DataBaseService._internal();

  factory DataBaseService() {
    return _singleton;
  }

  DataBaseService._internal();
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final expensesRef = _firestore
      .collection('users')
      .doc('elon@spacex.com')
      .collection('expenses');
      
  static Future<String> insertExpense(Expense model) async {
    // TODO: query to insert a new Expense into Database
    final expense = Expense(
        amount: model.amount,
        description: model.description,
        dateTime: model.dateTime,
        type: model.type,
        labels: model.labels);
    final json = expense.toJson();
    final ref = await expensesRef.add(json);
    return ref.id;
  }

  static Future<List<Expense>> getExpenses() async {
    try {
      List<Expense> expenses = [];
      final querySnapshot = await expensesRef.get();
      querySnapshot.docs.forEach((doc) {
        final expense = Expense.fromJson(doc.data());
        expenses.add(expense);
      });
      return expenses;
    } catch (_) {
      print('Exception occured $_');
      return [];
    }
  }

  static Future<Expense?> getLastExpense() async {
    try {
      final expenseListInDesc =
          await expensesRef.orderBy('date', descending: true).get();
      final docs = expenseListInDesc.docs;
      if (docs.isEmpty) {
        return null;
      } else {
        final expenseMap = docs.first.data();
        return Expense.fromJson(expenseMap);
      }
    } catch (_) {
      print('Exception occured $_');
      return null;
    }
  }

  static Future<void> removeExpense(String docId) async {
    await expensesRef.doc(docId).delete();
  }
}
