class ExpenseModal {
  double amount;
  String description;

  ExpenseModal(this.amount,this.description);
  
  // double get getAmount => amount;
  // String get getDescription => description;

  set setAmount(double amount) => amount = amount;
  set expenseDescription(String desc) => description = desc;
}
