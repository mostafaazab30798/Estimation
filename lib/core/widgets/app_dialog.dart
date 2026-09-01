import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Canonical dialog chrome for non-gameplay decisions.
///
/// Gameplay-critical bid, declaration, trick, and score dialogs intentionally
/// keep their specialized presentation and do not use this component.
class AppAlertDialog extends StatelessWidget {
  const AppAlertDialog({
    super.key,
    this.icon,
    this.iconPadding,
    this.iconColor,
    this.title,
    this.titlePadding = const EdgeInsets.fromLTRB(24, 24, 24, 0),
    this.titleTextStyle,
    this.content,
    this.contentPadding = AppTheme.dialogContentPadding,
    this.contentTextStyle,
    this.actions,
    this.actionsPadding = const EdgeInsets.fromLTRB(20, 4, 20, 20),
    this.actionsAlignment = MainAxisAlignment.end,
    this.actionsOverflowAlignment,
    this.actionsOverflowDirection,
    this.actionsOverflowButtonSpacing,
    this.buttonPadding,
    this.scrollable = false,
  });

  final Widget? icon;
  final EdgeInsetsGeometry? iconPadding;
  final Color? iconColor;
  final Widget? title;
  final EdgeInsetsGeometry? titlePadding;
  final TextStyle? titleTextStyle;
  final Widget? content;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? contentTextStyle;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? actionsPadding;
  final MainAxisAlignment? actionsAlignment;
  final OverflowBarAlignment? actionsOverflowAlignment;
  final VerticalDirection? actionsOverflowDirection;
  final double? actionsOverflowButtonSpacing;
  final EdgeInsetsGeometry? buttonPadding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: icon,
      iconPadding: iconPadding,
      iconColor: iconColor,
      title: title,
      titlePadding: titlePadding,
      titleTextStyle: titleTextStyle,
      content: content,
      contentPadding: contentPadding,
      contentTextStyle: contentTextStyle,
      actions: actions,
      actionsPadding: actionsPadding,
      actionsAlignment: actionsAlignment,
      actionsOverflowAlignment: actionsOverflowAlignment,
      actionsOverflowDirection: actionsOverflowDirection,
      actionsOverflowButtonSpacing: actionsOverflowButtonSpacing,
      buttonPadding: buttonPadding,
      scrollable: scrollable,
      backgroundColor: AppTheme.dialogSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 18,
      shadowColor: const Color(0x8C000000),
      insetPadding: AppTheme.dialogInset,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(AppTheme.dialogRadius),
        ),
        side: BorderSide(color: Color(0x2E94B4C1)),
      ),
    );
  }
}
