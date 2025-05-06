import 'package:flutter/material.dart';

class MyDialogs {
  const MyDialogs._(); // Prevent instantiation

static void success(BuildContext context, {String? title, String? message}) {
  _showDialog(
    context: context,
    title: title ?? 'Success',
    message: message ?? 'Changes have been applied successfully.',
  );
}

static void error(
  BuildContext context, {
  String? title,
  String? message,
  String prefix = 'Changes could not be applied: ',
}) {
  _showDialog(
    context: context,
    title: title ?? 'Error',
    message: message != null ? '$prefix$message' : prefix,
  );
}

  static void _showDialog({
    required BuildContext context,
    required String title,
    required String message,
    int popCount = 0,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close dialog
                for (int i = 0; i < popCount; i++) {
                  Navigator.of(context).maybePop(); // Pop screens
                }
              },
            ),
          ],
        );
      },
    );
  }
}
