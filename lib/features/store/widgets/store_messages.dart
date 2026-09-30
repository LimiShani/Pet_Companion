import 'package:flutter/material.dart';

/// Shows a short message at the bottom of the screen, replacing any
/// message that is still up.
void showStoreMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 3)));
}
