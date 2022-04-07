import 'package:expense_manager/constants/exports.dart';
import 'package:flutter/material.dart';

class EMInputField extends StatefulWidget {
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final String? hintText;
  final String? labelText;
  final Function(String)? onChange;
  final Function(String)? onSubmit;
  final int? maxLength;
  final int? maxLines;
  final bool autoFocus;
  const EMInputField(
      {Key? key,
      this.controller,
      this.hintText,
      this.keyboardType = TextInputType.text,
      this.maxLength,
      this.labelText,
      this.onSubmit,
      this.maxLines,
      this.autoFocus = false,
      this.onChange})
      : super(key: key);

  @override
  State<EMInputField> createState() => _EMInputFieldState();
}

class _EMInputFieldState extends State<EMInputField> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    controller = widget.controller ?? TextEditingController();
  }

  late final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      cursorColor: Colors.white,
      keyboardType: widget.keyboardType,
      style: ExpenseTheme.inputTextStyle,
      maxLength: widget.maxLength,
      maxLines: widget.maxLines,
      autofocus: widget.autoFocus,
      onSubmitted: (x) => widget.onSubmit!(x),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: ExpenseTheme.inputTextStyle,
        prefixStyle: ExpenseTheme.inputTextStyle,
        counterText: "",
        labelText: widget.labelText,
        prefixText: widget.labelText,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        labelStyle: ExpenseTheme.inputTextStyle,
        focusedBorder: inputBorder,
        border: inputBorder,
        filled: true,
        fillColor: Colors.black38,
      ),
      onTap: () {},
    );
  }
}
