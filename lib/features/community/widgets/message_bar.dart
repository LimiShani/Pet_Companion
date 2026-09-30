import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';

/// A text field with a round send button, pinned under a list: the comment
/// field of a post and the message field of a chat room.
class MessageBar extends StatelessWidget {
  const MessageBar({
    super.key,
    required this.controller,
    required this.hint,
    required this.sendTooltip,
    required this.onSend,
    this.sending = false,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String hint;
  final String sendTooltip;
  final VoidCallback onSend;

  /// Shows a spinner in the send button and disables it.
  final bool sending;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 8, AppSpacing.screen, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: inputFormatters,
              style: AppText.body.copyWith(fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppText.body.copyWith(fontSize: 15, color: AppColors.brown.withValues(alpha: 0.6)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: sending ? null : onSend,
            tooltip: sendTooltip,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.coralDark,
              foregroundColor: AppColors.white,
              disabledBackgroundColor: AppColors.coralDark.withValues(alpha: 0.6),
              disabledForegroundColor: AppColors.white,
              fixedSize: const Size(48, 48),
            ),
            icon: sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.white),
                  )
                : const Icon(Icons.send_rounded, size: 22),
          ),
        ],
      ),
    );
  }
}
