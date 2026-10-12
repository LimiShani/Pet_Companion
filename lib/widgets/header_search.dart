import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'coral_header.dart';

/// Search that opens from the coral header instead of taking a row of its
/// own on the page.
///
/// A screen shows a [HeaderSearchButton] among its header actions. A tap
/// sets the screen's own "searching" flag, and while it is set the screen
/// puts a [HeaderSearchField] in the header's `bottom` in place of its
/// segmented control. Closing the field clears the query and gives the
/// segments back. The query itself stays in the screen's state (usually a
/// provider), so the list below filters as the owner types.
class HeaderSearchButton extends StatelessWidget {
  const HeaderSearchButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final String tooltip;
  final VoidCallback onPressed;

  /// True while a query is applied (the field closed but results still
  /// filtered): the icon gets a small dot.
  final bool active;

  static const buttonKey = Key('header-search-button');

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: active,
      smallSize: 9,
      backgroundColor: AppColors.yellow,
      offset: const Offset(-6, 6),
      child: CoralHeaderAction(
        key: buttonKey,
        icon: Icons.search_rounded,
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

/// The search field in the header's `bottom`: white, focused when it
/// opens, a clear button while there is text, and a close button that
/// ends the search (clears the query and calls [onClose]).
class HeaderSearchField extends StatefulWidget {
  const HeaderSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClose,
    required this.clearTooltip,
    required this.closeTooltip,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onClose;
  final String clearTooltip;
  final String closeTooltip;

  static const fieldKey = Key('header-search-field');
  static const closeKey = Key('header-search-close');

  @override
  State<HeaderSearchField> createState() => _HeaderSearchFieldState();
}

class _HeaderSearchFieldState extends State<HeaderSearchField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _close() {
    if (widget.controller.text.isNotEmpty) {
      widget.controller.clear();
      widget.onChanged('');
    }
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => TextField(
              key: HeaderSearchField.fieldKey,
              controller: widget.controller,
              focusNode: _focus,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textInputAction: TextInputAction.search,
              style: AppText.bodyLarge.copyWith(color: AppColors.ink),
              decoration: InputDecoration(
                hintText: widget.hint,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                prefixIcon: const AppIcon(
                  Icons.search_rounded,
                  color: AppColors.brown,
                ),
                suffixIcon: widget.controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: widget.clearTooltip,
                        icon: const AppIcon(
                          Icons.close_rounded,
                          color: AppColors.brown,
                        ),
                        onPressed: () {
                          widget.controller.clear();
                          widget.onChanged('');
                        },
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        CoralHeaderAction(
          key: HeaderSearchField.closeKey,
          icon: Icons.close_rounded,
          tooltip: widget.closeTooltip,
          onPressed: _close,
        ),
      ],
    );
  }
}
