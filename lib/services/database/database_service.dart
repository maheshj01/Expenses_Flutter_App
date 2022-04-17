import 'package:expense_manager/model/model.dart';

class DataBaseService {
  static final DataBaseService _singleton = DataBaseService._internal();

  factory DataBaseService() {
    return _singleton;
  }

  DataBaseService._internal();

  static Future<int> insertExpense(Expense model, double total) async {
    // TODO: query to insert a new Expense into Database
    final expense = Expense(
        amount: model.amount,
        description: model.description,
        total: total,
        datetime: model.datetime ?? DateTime.now(),
        type: model.type!,
        label: model.label,
        isDeleted: false);
    final saved = await expense.save();
    if (expense.saveResult!.success)
      print(expense.saveResult.toString());
    else
      print("failed to save to database ${expense.saveResult!.errorMessage}");
    await getExpenses().then((expenseList) {
      print("length = " + expenseList.length.toString());
      print("total = " + expenseList[expenseList.length - 1].total.toString());
    });
    return saved!;
  }

  static Future<List<Expense>> getExpenses() async {
    try {
      final expenses = await Expense().select().toList();
      return expenses;
    } catch (_) {
      print('Exception occured $_');
      return [];
    }
  }

  static Future<Expense?> getLastExpense() async {
    try {
      final expenseListInDesc =
          await Expense().select().orderByDesc('id').toList();
      if (expenseListInDesc.isEmpty) {
        return null;
      } else {
        return expenseListInDesc[0];
      }
    } catch (_) {
      print('Exception occured $_');
      return null;
    }
  }
}
