import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/l10n.dart';

Future<bool> launchOrExplain(
  BuildContext context, {
  required Future<bool> Function() launch,
  required String problem,
  required String copyLabel,
  required String copyText,
  bool copyIsNumber = false,
}) async {
  final opened = await launch();
  if (opened || !context.mounted) return opened;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(problem),
      content: SelectableText(
        copyText,
        textDirection: copyIsNumber
            ? TextDirection.ltr
            : directionOfText(copyText, fallback: Directionality.of(context)),
        textAlign: TextAlign.start,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: copyText));
            Navigator.of(context).pop();
          },
          child: Text(copyLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonClose),
        ),
      ],
    ),
  );
  return false;
}
