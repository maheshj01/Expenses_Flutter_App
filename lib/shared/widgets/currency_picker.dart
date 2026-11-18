import 'package:flutter/material.dart';

const supportedCurrencies = {
  'USD': 'US Dollar',
  'INR': 'Indian Rupee',
  'EUR': 'Euro',
  'GBP': 'British Pound',
  'CAD': 'Canadian Dollar',
  'AUD': 'Australian Dollar',
  'SGD': 'Singapore Dollar',
  'AED': 'UAE Dirham',
  'JPY': 'Japanese Yen',
};

/// Bottom sheet listing currencies. Returns the picked ISO code.
Future<String?> showCurrencyPicker(BuildContext context, {required String current}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (context) => ListView(
      shrinkWrap: true,
      children: [
        for (final MapEntry(key: code, value: name) in supportedCurrencies.entries)
          ListTile(
            title: Text(name),
            subtitle: Text(code),
            trailing: code == current ? const Icon(Icons.check_rounded) : null,
            onTap: () => Navigator.pop(context, code),
          ),
      ],
    ),
  );
}
