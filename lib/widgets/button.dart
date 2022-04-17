import 'package:flutter/material.dart';

enum Button { elevated, outlined }


class EmButton extends StatefulWidget {
  final String text;
  final Function onTap;
  final Button type;
  const EmButton(
      {Key? key,
      required this.onTap,
      required this.text,
      this.type = Button.elevated})
      : super(key: key);

  @override
  State<EmButton> createState() => _EmButtonState();
}

class _EmButtonState extends State<EmButton> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (widget.type == Button.elevated) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: Size(size.width, 48),
          maximumSize: Size(size.width, 48),
        ),
        onPressed: () => widget.onTap(),
        child: Text(
          '${widget.text}',
          style: TextStyle(color: Colors.white),
        ),
      );
    } else {
      return OutlinedButton(
          style: OutlinedButton.styleFrom(
              minimumSize: Size(size.width, 48),
              maximumSize: Size(size.width, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: BorderSide(
                color: Colors.red,
              )),
          onPressed: () => widget.onTap(),
          child: Text('${widget.text}'));
    }
  }
}
