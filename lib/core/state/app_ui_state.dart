import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight UI state provider replacing FFAppState.
///
/// Only contains UI-specific state. Bluetooth state is managed by BluetoothBloc.
class AppUiState extends ChangeNotifier {
  static const String _activeItemKey = 'app_active_item_id';
  static const String _swipeHintShownKey = 'app_swipe_hint_shown';

  late SharedPreferences _prefs;
  bool _initialized = false;

  // ============== Filter State ==============

  /// Selected date for filtering events
  DateTime? _datePicked;
  DateTime? get datePicked => _datePicked;
  set datePicked(DateTime? value) {
    _datePicked = value;
    notifyListeners();
  }

  /// Toggle between today's count vs total count
  bool _isTodayToggle = false;
  bool get isTodayToggle => _isTodayToggle;
  set isTodayToggle(bool value) {
    _isTodayToggle = value;
    notifyListeners();
  }

  /// Show counter mode in items list
  bool _showCounter = false;
  bool get showCounter => _showCounter;
  set showCounter(bool value) {
    _showCounter = value;
    notifyListeners();
  }

  /// Current page in event log pagination
  int _currentLogPage = 0;
  int get currentLogPage => _currentLogPage;
  set currentLogPage(int value) {
    _currentLogPage = value;
    notifyListeners();
  }

  /// Filter to show only events after last reset
  bool _showAfterResetOnly = false;
  bool get showAfterResetOnly => _showAfterResetOnly;
  set showAfterResetOnly(bool value) {
    _showAfterResetOnly = value;
    notifyListeners();
  }

  /// Trigger refresh flag
  bool _toggleRefresh = false;
  bool get toggleRefresh => _toggleRefresh;
  void triggerRefresh() {
    _toggleRefresh = !_toggleRefresh;
    notifyListeners();
  }

  // ============== Active Item (Persisted) ==============

  /// ID of the currently active item (sent to ESP32 device)
  /// Persisted to SharedPreferences
  String _activeItemId = '';
  String get activeItemId => _activeItemId;
  set activeItemId(String value) {
    _activeItemId = value;
    if (_initialized) {
      _prefs.setString(_activeItemKey, value);
    }
    notifyListeners();
  }

  // ============== Swipe Hint (Persisted) ==============

  /// Whether the swipe hint animation has been shown
  bool _hasShownSwipeHint = false;
  bool get hasShownSwipeHint => _hasShownSwipeHint;

  /// Mark swipe hint as shown (persisted)
  void markSwipeHintShown() {
    _hasShownSwipeHint = true;
    if (_initialized) {
      _prefs.setBool(_swipeHintShownKey, true);
    }
  }

  // ============== Initialization ==============

  /// Initialize persisted state from SharedPreferences
  Future<void> initialize() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();
    _activeItemId = _prefs.getString(_activeItemKey) ?? '';
    _hasShownSwipeHint = _prefs.getBool(_swipeHintShownKey) ?? false;
    _initialized = true;
    notifyListeners();
  }

  /// Clear all state (e.g., on logout)
  void clear() {
    _datePicked = null;
    _isTodayToggle = false;
    _showCounter = false;
    _currentLogPage = 0;
    _showAfterResetOnly = false;
    _toggleRefresh = false;
    // Don't clear activeItemId - it should persist across sessions
    notifyListeners();
  }

  /// Clear active item (e.g., when item is deleted)
  void clearActiveItem() {
    _activeItemId = '';
    if (_initialized) {
      _prefs.remove(_activeItemKey);
    }
    notifyListeners();
  }

  /// Set active item by ID
  void setActiveItem(String itemId) {
    activeItemId = itemId;
  }
}
