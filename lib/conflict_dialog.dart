import 'package:flutter/material.dart';
import 'cart_item.dart';

class ConflictDialog extends StatelessWidget {
  final Map<int, List<CartItem>> conflicts;

  const ConflictDialog({super.key, required this.conflicts});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('⚠️ Stock Conflict Detected'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: conflicts.entries.expand((entry) {
            final txId = entry.key;
            final items = entry.value;
            return [
              Text('Transaction #$txId couldn’t be fully synced.'),
              ...items.map((item) => Text('- ${item.productName} x${item.quantity}')),
              const Divider(),
            ];
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Ignore (sync others)'),
        ),
        ElevatedButton(
          onPressed: () {
            // 👉 Here: implement refund-processing logic
            // e.g., DatabaseHelper.instance.insertRefund(...);
            Navigator.pop(context);
          },
          child: const Text('Process Refund'),
        ),
      ],
    );
  }
}
