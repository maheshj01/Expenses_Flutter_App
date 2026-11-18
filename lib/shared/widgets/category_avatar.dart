import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/entities/category.dart';

class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar(this.category, {super.key, this.size = 40});

  final Category? category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: category == null ? c.sunk : c.categoryTile(category!.color),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(category?.emoji ?? '•', style: TextStyle(fontSize: size * 0.45)),
    );
  }
}
