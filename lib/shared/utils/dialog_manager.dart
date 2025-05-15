import 'dart:async';

class DialogManager {
  // Singleton instance
  static final DialogManager _instance = DialogManager._internal();

  // Factory constructor to return the singleton instance
  factory DialogManager() {
    return _instance;
  }

  // Private constructor for singleton
  DialogManager._internal();

  // Dialog state tracking
  bool _isDialogShowing = false;
  String? _currentDialogContext;
  Timer? _staleStateTimer;

  /// Check if any dialog is currently showing
  bool get isDialogShowing => _isDialogShowing;

  /// Start tracking a dialog being shown
  void showingDialog(String context) {
    _cancelStaleTimer();

    _isDialogShowing = true;
    _currentDialogContext = context;

    // Start a timer to automatically clear stale dialog state after 3 minutes
    // This prevents state from getting stuck if a dialog is never properly closed
    _staleStateTimer = Timer(const Duration(minutes: 3), () {
      print('DIALOG MANAGER: Stale dialog state detected, auto-resetting');
      reset();
    });
  }

  /// Mark dialog as closed
  void dialogClosed() {
    _cancelStaleTimer();

    _isDialogShowing = false;
    _currentDialogContext = null;
  }

  /// Reset the dialog state
  void reset() {
    _cancelStaleTimer();
    _isDialogShowing = false;
    _currentDialogContext = null;
  }

  /// Cancel the stale state timer if it exists
  void _cancelStaleTimer() {
    if (_staleStateTimer != null) {
      _staleStateTimer!.cancel();
      _staleStateTimer = null;
    }
  }
}