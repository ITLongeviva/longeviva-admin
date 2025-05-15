import 'package:flutter/material.dart';

class DialogService {
  /// Shows a dialog with smooth animation transitions
  ///
  /// Parameters:
  /// - context: BuildContext
  /// - dialogBuilder: Function that returns the dialog content widget
  /// - barrierDismissible: Whether clicking outside the dialog dismisses it
  /// - barrierColor: Color of the background barrier
  static Future<T?> showAnimatedDialog<T>({
    required BuildContext context,
    required Widget Function(BuildContext) dialogBuilder,
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
    bool useSafeArea = true,
    bool useRootNavigator = true,
    RouteSettings? routeSettings,
    Duration transitionDuration = const Duration(milliseconds: 150),
    Curve transitionCurve = Curves.easeOutQuad,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel ?? MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: barrierColor ?? Colors.black54,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      pageBuilder: (BuildContext buildContext, Animation<double> animation, Animation<double> secondaryAnimation) {
        final Widget dialog = dialogBuilder(buildContext);
        return useSafeArea ? SafeArea(child: dialog) : dialog;
      },
      transitionDuration: transitionDuration,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: transitionCurve,
        );

        return AnimatedBuilder(
          animation: curvedAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: Tween<double>(begin: 0.85, end: 1.0).evaluate(curvedAnimation),
              child: Opacity(
                opacity: Tween<double>(begin: 0.5, end: 1.0).evaluate(curvedAnimation),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );
  }

  /// A stateless version of showDialog that doesn't rebuild anything in the parent context
  ///
  /// This is particularly useful when you want to show a dialog without affecting the parent state
  static Future<T?> showIsolatedDialog<T>({
    required BuildContext context,
    required Widget dialogContent,
    bool barrierDismissible = true,
    Color? barrierColor,
    bool useRootNavigator = true,
    BorderRadius? borderRadius,
    EdgeInsets? insetPadding,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? Colors.black54,
      useRootNavigator: useRootNavigator, // This helps maintain parent state
      routeSettings: const RouteSettings(name: 'isolatedDialog'), // Name helps with debugging
      builder: (dialogContext) {
        return Dialog(
          insetPadding: insetPadding ?? const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(16),
          ),
          child: dialogContent,
        );
      },
    );
  }

  /// Shows a side drawer with smooth slide animation (for mobile)
  static Future<T?> showAnimatedDrawer<T>({
    required BuildContext context,
    required Widget Function(BuildContext) drawerBuilder,
    bool isEndDrawer = true,
    Duration transitionDuration = const Duration(milliseconds: 250),
    Curve transitionCurve = Curves.easeOutQuad,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black38,
      pageBuilder: (BuildContext buildContext, Animation<double> animation, Animation<double> secondaryAnimation) {
        return drawerBuilder(buildContext);
      },
      transitionDuration: transitionDuration,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: transitionCurve,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(isEndDrawer ? 1.0 : -1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );
      },
    );
  }

  /// Shows a bottom sheet with smooth animation
  static Future<T?> showAnimatedBottomSheet<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    double initialChildSize = 0.5,
    double minChildSize = 0.25,
    double maxChildSize = 0.85,
    BorderRadiusGeometry? borderRadius,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
          builder: (context, scrollController) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                color: backgroundColor ?? Colors.white,
                borderRadius: borderRadius ?? const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const ClampingScrollPhysics(),
                child: builder(context),
              ),
            );
          },
        );
      },
    );
  }
}