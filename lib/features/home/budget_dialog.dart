import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

Future<void> showBudgetDialog(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(settingsProvider);
  final result = await showDialog<int>(
    context: context,
    builder: (context) => _BudgetDialog(
      initialCents: settings.hasBudget ? settings.monthlyBudgetCents : null,
      symbol: ref.read(moneyFormatProvider).symbol,
    ),
  );
  if (result != null) {
    await ref.read(settingsProvider.notifier).update(settings.copyWith(monthlyBudgetCents: result));
  }
}

/// Owns its text controller, so it is disposed only once the dialog has left
/// the tree: the closing animation still rebuilds the field after `pop`.
class _BudgetDialog extends StatefulWidget {
  const _BudgetDialog({required this.initialCents, required this.symbol});

  /// The current budget, or null when there is none.
  final int? initialCents;
  final String symbol;

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  late final _controller = TextEditingController(
    text: widget.initialCents == null ? '' : (widget.initialCents! ~/ 100).toString(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Monthly spending budget'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Spending only. Savings and income don’t count against it.'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(prefixText: '${widget.symbol} ', hintText: '1350'),
          ),
        ],
      ),
      actions: [
        if (widget.initialCents != null)
          TextButton(onPressed: () => Navigator.pop(context, 0), child: const Text('Remove')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, (int.tryParse(_controller.text) ?? 0) * 100),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
