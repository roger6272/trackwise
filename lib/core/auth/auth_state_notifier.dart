import 'package:flutter/material.dart';

/// Global navigator key for GoRouter.
GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Auth state notifier for GoRouter's refreshListenable.
///
/// Provides auth state as a ChangeNotifier so the router rebuilds when auth changes.
/// Uses simple properties instead of depending on FlutterFlow's BaseAuthUser.
class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier._();

  static AuthStateNotifier? _instance;
  static AuthStateNotifier get instance => _instance ??= AuthStateNotifier._();

  String? _uid;
  String? _initialUid;
  bool _isLoggedIn = false;
  bool _initiallyLoggedIn = false;
  bool _onboardingCompleted = true; // Default to true to avoid redirect flash
  bool showSplashImage = true;
  String? _redirectLocation;

  /// Determines whether the app will refresh and build again when a sign
  /// in or sign out happens. This is useful when the app is launched or
  /// on an unexpected logout. However, this must be turned off when we
  /// intend to sign in/out and then navigate or perform any actions after.
  /// Otherwise, this will trigger a refresh and interrupt the action(s).
  bool notifyOnAuthChange = true;

  String? get uid => _uid;
  bool get loading => _uid == null && !_isLoggedIn && showSplashImage;
  bool get loggedIn => _isLoggedIn;
  bool get initiallyLoggedIn => _initiallyLoggedIn;
  bool get onboardingCompleted => _onboardingCompleted;
  bool get needsOnboarding => _isLoggedIn && !_onboardingCompleted;
  bool get shouldRedirect => loggedIn && _redirectLocation != null;

  String getRedirectLocation() => _redirectLocation!;
  bool hasRedirect() => _redirectLocation != null;
  void setRedirectLocationIfUnset(String loc) => _redirectLocation ??= loc;
  void clearRedirectLocation() => _redirectLocation = null;

  /// Mark as not needing to notify on a sign in / out when we intend
  /// to perform subsequent actions (such as navigation) afterwards.
  void updateNotifyOnAuthChange(bool notify) => notifyOnAuthChange = notify;

  /// Update auth state with user info from AuthBloc.
  void updateAuthState({
    required String? uid,
    required bool isLoggedIn,
    bool? onboardingCompleted,
  }) {
    final shouldUpdate = _uid != uid || _isLoggedIn != isLoggedIn ||
        (onboardingCompleted != null && _onboardingCompleted != onboardingCompleted);

    // Set initial state on first update
    if (_initialUid == null && uid != null) {
      _initialUid = uid;
      _initiallyLoggedIn = isLoggedIn;
    }

    _uid = uid;
    _isLoggedIn = isLoggedIn;
    if (onboardingCompleted != null) {
      _onboardingCompleted = onboardingCompleted;
    }

    // Refresh the app on auth change unless explicitly marked otherwise.
    if (notifyOnAuthChange && shouldUpdate) {
      notifyListeners();
    }
    // Once again mark the notifier as needing to update on auth change
    updateNotifyOnAuthChange(true);
  }

  void stopShowingSplashImage() {
    showSplashImage = false;
    notifyListeners();
  }
}
