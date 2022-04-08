import 'package:expense_manager/constants/exports.dart';
import 'package:expense_manager/model/spend.dart';
import 'package:expense_manager/widgets/input_field.dart';
import 'package:flutter/material.dart';

class EmBottomSheet extends StatefulWidget {
  final Function(Spend) onSubmit;
  const EmBottomSheet({Key? key, required this.onSubmit}) : super(key: key);

  @override
  State<EmBottomSheet> createState() => _EmBottomSheetState();
}

class _EmBottomSheetState extends State<EmBottomSheet> {
  Widget _expenseDescriptionField() {
    return EMInputField(
      controller: descriptionController,
      keyboardType: TextInputType.text,
      maxLines: 3,
      maxLength: 100,
      autoFocus: false,
      hintText: "What is this for ?",
      onChange: (x) {},
    );
  }

  Widget _expenseAmountField() {
    return Container(
      padding: EdgeInsets.all(10),
      width: MediaQuery.of(context).size.width / 2,
      child: EMInputField(
        controller: amountController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        autoFocus: true,
        hintText: "0",
        labelText: '$rupeeSymbol',
        onChange: (x) {},
      ),
    );
  }

  Spend spend = Spend(value: 0, type: SpendType.once, description: '');
  int selectedIndex = 0;
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20), topRight: Radius.circular(20))),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  EmIcon(Icons.clear, onTap: () {
                    amountController.clear();
                    descriptionController.clear();
                    Navigator.pop(context);
                  }),
                  _expenseAmountField(),
                  EmIcon(Icons.done, onTap: () {
                    if (amountController.text.isEmpty ||
                        descriptionController.text.isEmpty) {
                      // Navigator.pop(context);
                      return;
                    }
                    var amount = double.parse(amountController.text);
                    var description = descriptionController.text;

                    /// TODO: WorK on custom scrollview
                    final spentValue = spend.copyWith(
                        value: amount,
                        description: description,
                        type: expenseTypes[selectedIndex]);
                    amountController.clear();
                    descriptionController.clear();
                    Navigator.pop(context);
                    widget.onSubmit(spentValue);
                  })
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: ToggleButtons(
                  children: <Widget>[
                    for (int i = 0; i < expenseTypes.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Text(
                          '${expenseTypes[i].name}'.capitalize(),
                        ),
                      ),
                  ],
                  onPressed: (x) {
                    setState(() {
                      selectedIndex = x;
                    });
                  },
                  isSelected: [for (int i = 0; i < 3; i++) selectedIndex == i],
                ),
              ),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 10),
                child: _expenseDescriptionField(),
              ),
              SizedBox(
                height: 20,
              ),
            ],
          )),
    );
  }
}
