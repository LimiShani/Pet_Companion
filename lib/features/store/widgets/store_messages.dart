import 'package:flutter/material.dart';

/// Shows a short message at the bottom of the screen, replacing any
/// message that is still up.
void showStoreMessage(BuildContext context, String text) =>
    showStoreMessageOn(ScaffoldMessenger.of(context), text);

/// As [showStoreMessage], for when the page that asked is about to close:
/// take the messenger first, close the page, then show the message.
void showStoreMessageOn(ScaffoldMessengerState messenger, String text) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 3)));
}
