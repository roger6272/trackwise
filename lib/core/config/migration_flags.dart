/// Feature flags for gradual FlutterFlow to Clean Architecture migration.
///
/// These flags control which implementation is used for each part of the app.
/// The migration follows a "strangler fig" pattern:
/// 1. Start with all flags FALSE (use FF implementation)
/// 2. Enable one flag at a time after testing the new implementation
/// 3. Only delete FF code after all flags are TRUE and stable
///
/// See PRD: .claude/prds/flutterflow-migration.md
class MigrationFlags {
  MigrationFlags._();

  // ============================================
  // Phase 1: Foundation
  // ============================================

  /// Use new AppTheme instead of FlutterFlowTheme
  static const useNewTheme = true;

  /// Use new AppRouter instead of FF createRouter
  /// When false: main.dart uses createRouter() from flutter_flow/nav/nav.dart
  /// When true: main.dart uses AppRouter.createRouter() from core/router/app_router.dart
  static const useNewRouter = true;

  // ============================================
  // Phase 2: Page Migration
  // ============================================

  /// Use new ProfilePage instead of ProfilePageWidget
  /// Requires: ProfileBloc and AuthBloc to be provided in main.dart
  static const useNewProfilePage = false;

  /// Use new auth pages (LoginPage, SignupPage, ForgotPasswordPage)
  /// instead of Auth2LoginWidget, Auth2CreateWidget, Auth2ForgotPasswordWidget
  static const useNewAuthPages = true;

  /// Use new ItemsListPage as main page instead of MainPageWidget
  /// This is the most complex migration - requires all BLoCs and auth to be ready
  static const useNewMainPage = false;

  // ============================================
  // Helpers
  // ============================================

  /// Returns true if any migration flag is enabled
  static bool get anyEnabled =>
      useNewTheme ||
      useNewRouter ||
      useNewProfilePage ||
      useNewAuthPages ||
      useNewMainPage;

  /// Returns true if all migration flags are enabled (migration complete)
  static bool get allEnabled =>
      useNewTheme &&
      useNewRouter &&
      useNewProfilePage &&
      useNewAuthPages &&
      useNewMainPage;
}
