import 'package:expense_manager/constants/exports.dart';
import 'package:expense_manager/model/spend.dart';
import 'package:expense_manager/utils/settings.dart';
import 'package:expense_manager/widgets/filter_sheet.dart';
import 'package:expense_manager/widgets/input_field.dart';
import 'package:flutter/material.dart';
import 'package:searchfield/searchfield.dart';

class ExpenseSheet extends StatefulWidget {
  final Function(Spend) onSubmit;
  const ExpenseSheet({Key? key, required this.onSubmit}) : super(key: key);

  @override
  State<ExpenseSheet> createState() => ExpenseSheetState();
}

class ExpenseSheetState extends State<ExpenseSheet> {
  Widget _expenseDescriptionField() {
    return EMInputField(
      controller: descriptionController,
      keyboardType: TextInputType.text,
      maxLines: 3,
      maxLength: 100,
      autoFocus: false,
      hintText: "What is this for ?",
      onChange: (x) {},
      style: ExpenseTheme.rupeeStyle,
      onSubmit: (x) => submit(),
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
        labelText: '${Settings.currency.symbol}',
        onSubmit: (x) {},
        onChange: (x) {},
      ),
    );
  }

  void submit() {
    var description = descriptionController.text;
    var labelField = labelController.text;
    if (amountController.text.isEmpty ||
        descriptionController.text.isEmpty ||
        labelField.isNotEmpty) {
      // Navigator.pop(context);
      return;
    }
    var amount = double.parse(amountController.text);
    var label = labels.join(',');

    /// TODO: WorK on custom scrollview
    final spentValue = spend.copyWith(
        value: amount,
        description: description,
        label: label,
        type: expenseTypes[selectedIndex]);
    amountController.clear();
    descriptionController.clear();
    Navigator.pop(context);
    widget.onSubmit(spentValue);
  }

  void deleteLabel(String x) {
    labels.remove(x);
    // if (labelController.text.isEmpty) {
    setState(() {});
    //     isAddLabel = false;
    // }
  }

  void addLabel(String x, {bool isTap = false}) {
    if (labelController.text.isEmpty && !isTap) {
      setState(() {
        isAddLabel = false;
      });
      return;
    }
    if (!labels.contains(x.toLowerCase())) {
      setState(() {
        labels.add(x.toLowerCase().trim());
        if (!isTap) {
          isAddLabel = false;
        }
      });
      labelController.clear();
    }
  }

  Spend spend = Spend(value: 0, type: SpendType.once, description: '');
  int selectedIndex = 0;
  bool isAddLabel = false;
  List<String> labels = [];
  @override
  Widget build(BuildContext context) {
    return Column(
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
            EmIcon(Icons.done, onTap: submit)
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
        SizedBox(
          height: labels.isEmpty ? 0 : 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (int i = 0; i < labels.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Chip(
                      onDeleted: () => deleteLabel(labels[i]),
                      label: Text(
                        '${labels[i]}',
                        style: ExpenseTheme.rupeeStyle,
                      )),
                ),
            ],
          ),
        ),
        InkWell(
          onTap: () {
            setState(() {
              isAddLabel = true;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0) +
                EdgeInsets.only(top: 8, bottom: 16),
            child: Row(children: [
              Icon(Icons.add, size: 30),
              Text(
                'Add Label',
                style: ExpenseTheme.rupeeStyle,
              )
            ]),
          ),
        ),
        isAddLabel
            ? Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0) +
                        EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Expanded(
                            child: StreamBuilder<List<String>>(
                                stream: expenseService.labelStream,
                                builder: (BuildContext context,
                                    AsyncSnapshot<List<String>> snapshot) {
                                  final List<String>? labels =
                                      snapshot.data == null
                                          ? []
                                          : snapshot.data;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12.0),
                                    child: SearchField<String>(
                                      suggestions: labels!
                                          .map((e) =>
                                              SearchFieldListItem<String>(e,
                                                  child: Text(e)))
                                          .toList(),
                                      searchStyle: ExpenseTheme.rupeeStyle,
                                      controller: labelController,
                                      maxSuggestionsInViewPort: 3,
                                      hasOverlay: false,
                                      itemHeight: 40,
                                      onSubmit: (x) {
                                        if (!labels.contains(x.toLowerCase())) {
                                          labels.add(x.toLowerCase());
                                        }
                                        setState(() {});
                                        labelController.clear();
                                      },
                                      suggestionsDecoration: BoxDecoration(
                                          color: ExpenseTheme
                                              .colorScheme.background),
                                      suggestionItemDecoration: BoxDecoration(
                                          color: ExpenseTheme
                                              .colorScheme.background),
                                      searchInputDecoration: InputDecoration(
                                        hintText: 'e.g Entertainment',
                                        hintStyle: ExpenseTheme.rupeeStyle,
                                        prefixStyle: ExpenseTheme.rupeeStyle,
                                        counterText: "",
                                        floatingLabelBehavior:
                                            FloatingLabelBehavior.never,
                                        labelStyle: ExpenseTheme.rupeeStyle,
                                        enabledBorder: inputBorder,
                                        focusedBorder: inputBorder,
                                        border: inputBorder,
                                        filled: true,
                                        fillColor:
                                            Colors.black38.withOpacity(0.1),
                                      ),
                                    ),
                                  );

                                  // LabelsFilterWidget(
                                  //   labels: labels!,
                                  //   selectedlabels: labels,
                                  //   color: ExpenseTheme.colorScheme.primary,
                                  //   onTap: (x) {
                                  //     addLabel(x, isTap: true);
                                  //   },
                                  // );
                                })),
                        SizedBox(
                          width: 20,
                        ),
                        EmIcon(Icons.done,
                            size: 32,
                            onTap: () =>
                                addLabel(labelController.text, isTap: false))
                      ],
                    ),
                  ),
                ],
              )
            : SizedBox(),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 10),
          child: _expenseDescriptionField(),
        ),
        SizedBox(
          height: 20,
        ),
      ],
    );
  }
}
