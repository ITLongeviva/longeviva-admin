import 'package:flutter/material.dart';
import '../../backend/services/custom_alert_service.dart';
import '../../backend/services/dialog_service.dart';

// Extension methods on BuildContext for showing alerts and dialogs
extension ContextExtensions on BuildContext {
  // Alert methods
  void showSuccessAlert(String message, {Duration? duration}) {
    CustomAlertService().showSuccessAlert(
      context: this,
      message: message,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  void showErrorAlert(String message, {Duration? duration}) {
    CustomAlertService().showErrorAlert(
      context: this,
      message: message,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  void showWarningAlert(String message, {Duration? duration}) {
    CustomAlertService().showWarningAlert(
      context: this,
      message: message,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  void showForbiddenActionAlert(String message) {
    CustomAlertService().showErrorAlert(
      context: this,
      message: message,
      icon: Icons.block,
    );
  }

  // Dialog methods
  Future<T?> showAnimatedDialog<T>({
    required Widget Function(BuildContext) dialogBuilder,
    bool barrierDismissible = true,
    Color? barrierColor,
  }) {
    return DialogService.showAnimatedDialog<T>(
      context: this,
      dialogBuilder: dialogBuilder,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
    );
  }

  Future<T?> showAnimatedBottomSheet<T>({
    required Widget Function(BuildContext) builder,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    double initialChildSize = 0.5,
  }) {
    return DialogService.showAnimatedBottomSheet<T>(
      context: this,
      builder: builder,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor,
      initialChildSize: initialChildSize,
    );
  }

  Future<T?> showAnimatedDrawer<T>({
    required Widget Function(BuildContext) drawerBuilder,
    bool isEndDrawer = true,
  }) {
    return DialogService.showAnimatedDrawer<T>(
      context: this,
      drawerBuilder: drawerBuilder,
      isEndDrawer: isEndDrawer,
    );
  }
}