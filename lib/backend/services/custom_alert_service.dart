import 'package:flutter/material.dart';

import '../../shared/utils/colors.dart';

class CustomAlertService {
  // Singleton pattern to ensure only one overlay entry at a time
  static final CustomAlertService _instance = CustomAlertService._internal();
  factory CustomAlertService() => _instance;
  CustomAlertService._internal();

  // Track the current overlay entry to remove if needed
  OverlayEntry? _currentOverlay;

  /// Shows an error alert popup that automatically dismisses after a short duration
  ///
  /// Parameters:
  /// - context: BuildContext required to show the overlay
  /// - message: The error message to display
  /// - icon: Optional icon to show (defaults to error icon)
  /// - duration: How long to show the alert (defaults to 1 second)
  void showErrorAlert({
    required BuildContext context,
    required String message,
    IconData icon = Icons.error_outline,
    Duration duration = const Duration(seconds: 2),
  }) {
    // Dismiss any existing overlay first
    _dismissCurrentOverlay();

    // Create overlay entry
    _currentOverlay = OverlayEntry(
      builder: (context) => _AlertOverlay(
        message: message,
        icon: icon,
        backgroundColor: CustomColors.rossoSimone,
      ),
    );

    // Show the overlay
    Overlay.of(context).insert(_currentOverlay!);

    // Set up auto-dismiss
    Future.delayed(duration, () {
      _dismissCurrentOverlay();
    });
  }

  /// Shows a success alert popup
  void showSuccessAlert({
    required BuildContext context,
    required String message,
    IconData icon = Icons.check_circle_outline,
    Duration duration = const Duration(seconds: 2),
  }) {
    _dismissCurrentOverlay();

    _currentOverlay = OverlayEntry(
      builder: (context) => _AlertOverlay(
        message: message,
        icon: icon,
        backgroundColor: CustomColors.verdeAbisso,
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);

    Future.delayed(duration, () {
      _dismissCurrentOverlay();
    });
  }

  /// Shows a warning alert popup
  void showWarningAlert({
    required BuildContext context,
    required String message,
    IconData icon = Icons.warning_amber_outlined,
    Duration duration = const Duration(seconds: 2),
  }) {
    _dismissCurrentOverlay();

    _currentOverlay = OverlayEntry(
      builder: (context) => _AlertOverlay(
        message: message,
        icon: icon,
        backgroundColor: Colors.amber,
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);

    Future.delayed(duration, () {
      _dismissCurrentOverlay();
    });
  }

  // Private method to dismiss current overlay if it exists
  void _dismissCurrentOverlay() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}

/// Private widget for the alert overlay appearance and animation
class _AlertOverlay extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color backgroundColor;

  const _AlertOverlay({
    required this.message,
    required this.icon,
    required this.backgroundColor,
  });

  @override
  State<_AlertOverlay> createState() => _AlertOverlayState();
}

class _AlertOverlayState extends State<_AlertOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // Configure animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    color: CustomColors.biancoPuro,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CustomColors.biancoPuro,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: CustomColors.biancoPuro,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      CustomAlertService()._dismissCurrentOverlay();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}