import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

Future<void> showBudgetDialog(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(settingsProvider);
  final money = ref.read(moneyFormatProvider);
  final controller = TextEditingController(
    text: settings.hasBudget ? (settings.monthlyBudgetCents ~/ 100).toString() : '',
  );
  final result = await showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Monthly living budget'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Spending only. Investments and income don’t count against it.'),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(prefixText: '${money.symbol} ', hintText: '1350'),
          ),
        ],
      ),
      actions: [
        if (settings.hasBudget)
          TextButton(onPressed: () => Navigator.pop(context, 0), child: const Text('Remove')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, (int.tryParse(controller.text) ?? 0) * 100),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result != null) {
    await ref.read(settingsProvider.notifier).update(settings.copyWith(monthlyBudgetCents: result));
  }
}
