import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class SnackbarHelper {
  static void showSuccess(BuildContext context, String message, {String? title}) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.flatColored,
      title: title != null ? Text(title) : const Text('نجاح'),
      description: Text(message),
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 4),
      animationBuilder: (context, animation, alignment, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      borderRadius: BorderRadius.circular(12),
      boxShadow: highModeShadow,
      showProgressBar: false,
    );
  }

  static void showError(BuildContext context, String message, {String? title}) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.flatColored,
      title: title != null ? Text(title) : const Text('خطأ'),
      description: Text(message),
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 4),
      animationBuilder: (context, animation, alignment, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      borderRadius: BorderRadius.circular(12),
      boxShadow: highModeShadow,
      showProgressBar: false,
    );
  }

  static void showInfo(BuildContext context, String message, {String? title}) {
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.flatColored,
      title: title != null ? Text(title) : const Text('تنبيه'),
      description: Text(message),
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 4),
      animationBuilder: (context, animation, alignment, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      borderRadius: BorderRadius.circular(12),
      boxShadow: highModeShadow,
      showProgressBar: false,
    );
  }

  static void showWarning(BuildContext context, String message, {String? title}) {
    toastification.show(
      context: context,
      type: ToastificationType.warning,
      style: ToastificationStyle.flatColored,
      title: title != null ? Text(title) : const Text('تحذير'),
      description: Text(message),
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 4),
      animationBuilder: (context, animation, alignment, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      borderRadius: BorderRadius.circular(12),
      boxShadow: highModeShadow,
      showProgressBar: false,
    );
  }
}
