import 'package:flutter/material.dart';

class NotificationService {
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void showSyncStatus(BuildContext context, bool isOnline, {DateTime? lastSync}) {
    final message = isOnline 
        ? 'Online - ${lastSync != null ? 'Last sync: ${_formatDateTime(lastSync)}' : 'Ready to sync'}'
        : 'Offline - Changes will sync when back online';
    
    showInfo(context, message);
  }

  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

// utils/barcode_scanner.dart
// Note: This is a placeholder. You'll need to add a barcode scanning package
// like 'mobile_scanner' or 'barcode_scan2' to your pubspec.yaml

class BarcodeScanner {
  static Future<String?> scan() async {
    // Implement barcode scanning logic here
    // This is a placeholder that returns a sample barcode
    
    // Example with mobile_scanner package:
    // final result = await Navigator.push(
    //   context,
    //   MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    // );
    // return result;
    
    return null; // Return null if no barcode scanned
  }
}