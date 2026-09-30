import 'package:flutter/material.dart';

import '../../../widgets/empty_state.dart';

/// An [EmptyState] that fills a whole section or page ("nothing here yet",
/// "cannot load"): in the middle when there is room, and scrolling when
/// there is not, as on a small phone between a header and a message field.
class SectionState extends StatelessWidget {
  const SectionState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: EmptyState(
            icon: icon,
            title: title,
            message: message,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
        ),
      ),
    );
  }
}
