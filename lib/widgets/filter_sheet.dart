import 'package:expense_manager/constants/exports.dart';
import 'package:expense_manager/model/filter.dart';
import 'package:expense_manager/widgets/button.dart';
import 'package:expense_manager/widgets/widgets_helper.dart';
import 'package:flutter/material.dart';

class FilterSheet extends StatefulWidget {
  FilterModel filter;
  final Function(FilterModel) onFilterChange;
  FilterSheet({Key? key, required this.onFilterChange, required this.filter})
      : super(key: key);

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late FilterModel _filter;
  @override
  void initState() {
    super.initState();
    _filter = FilterModel(
      sortByDate: widget.filter.sortByDate,
      labels: widget.filter.labels,
      didSortChange: widget.filter.didSortChange,
    );
  }

  Future<void> onLabelTap(String x) async {
    if (x.isEmpty) return;
    if (!_filter.labels.contains(x)) {
      setState(() {
        _filter.labels.add(x);
      });
    } else {
      setState(() {
        _filter.labels.remove(x);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget filterTile(String text, {bool isSelected = false}) {
      return InkWell(
          onTap: () {
            setState(() {
              _filter.sortByDate = text == 'Date Created' ? true : false;
            });
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  text,
                  style: ExpenseTheme.textTheme.headline6!.copyWith(
                      fontWeight: isSelected
                          ? ExpenseTheme.bold
                          : ExpenseTheme.semiBold),
                ),
              ),
              isSelected
                  ? Icon(Icons.check, color: Colors.green, size: 24)
                  : SizedBox()
            ],
          ));
    }

    return Padding(
        padding: const EdgeInsets.only(left: 16.0, top: 16, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title('Sort by'),
            SizedBox(
              height: 6,
            ),
            filterTile('Date Created', isSelected: _filter.sortByDate),
            filterTile('Date Added', isSelected: !_filter.sortByDate),
            Divider(),
            title('Category'),
            StreamBuilder<List<String>>(
                stream: expenseService.labelStream,
                builder: (BuildContext context,
                    AsyncSnapshot<List<String>> labelSnapshot) {
                  return labelSnapshot.data == null ||
                          labelSnapshot.data!.isEmpty
                      ? SizedBox()
                      : LabelsFilterWidget(
                          labels: labelSnapshot.data!,
                          selectedlabels: _filter.labels,
                          color:
                              ExpenseTheme.colorScheme.primary.withOpacity(0.4),
                          onTap: (x) => onLabelTap(x),
                        );
                }),
            SizedBox(
              height: 80,
            ),
            Row(children: [
              Expanded(
                child: EmButton(
                  onTap: () {
                    Navigator.pop(context);
                    widget.filter.didSortChange =
                        widget.filter.sortByDate != _filter.sortByDate;
                    print('sort changes = ${widget.filter.didSortChange}');
                    // _filter.didLabelsChange =
                    //     _filter.labels != widget.filter.labels;
                    widget.filter = _filter;
                    widget.onFilterChange(_filter);
                  },
                  text: 'Apply',
                ),
              ),
              SizedBox(
                width: 8,
              ),
              Expanded(
                child: EmButton(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    text: 'Cancel'),
              ),
            ]),
            SizedBox(
              height: 24,
            )
          ],
        ));
  }
}

class LabelsFilterWidget extends StatelessWidget {
  const LabelsFilterWidget(
      {Key? key,
      this.onTap,
      required this.color,
      required this.labels,
      this.trailing,
      required this.selectedlabels})
      : super(key: key);
  final Function(String)? onTap;
  final Color color;
  final List<String> labels;
  final Widget? trailing;
  final List<String> selectedlabels;

  @override
  Widget build(BuildContext context) {
    final int length = trailing != null ? labels.length + 1 : labels.length;
    return Wrap(
        children: List.generate(length, (index) {
      if (trailing != null && index == length - 1) {
        return trailing!;
      }
      final label = labels[index];
      bool isSelected = selectedlabels.contains(label);
      return GestureDetector(
        onTap: () => onTap!(label),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Chip(
              backgroundColor:
                  isSelected ? color.withOpacity(1.0) : color.withOpacity(0.4),
              label: Text(
                label,
                style: ExpenseTheme.rupeeStyle.copyWith(
                  color: isSelected ? Colors.white : Colors.black,
                ),
              )),
        ),
      );
    }));
  }
}

class EmSliverAppBar extends SliverPersistentHeaderDelegate {
  final Widget child;
  EmSliverAppBar({required this.child});
  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    // TODO: implement build
    return child;
  }

  @override
  // TODO: implement maxExtent
  double get maxExtent => 200.0;

  @override
  // TODO: implement minExtent
  double get minExtent => 20.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}

class EmIcon extends StatelessWidget {
  EmIcon(this.iconData, {Key? key, required this.onTap, this.size = 40})
      : super(key: key);
  final IconData iconData;
  final Function onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(10),
      child: IconButton(
          icon: Icon(iconData),
          iconSize: size,
          color: Colors.white,
          onPressed: () => onTap()),
    );
  }
}