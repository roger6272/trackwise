import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_state_notifier.dart';
import '../widgets/app_shell.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/onboarding_page.dart';
import '../../features/items/presentation/pages/items_list_page.dart';
import '../../features/items/presentation/pages/item_detail_page.dart';
import '../../features/items/presentation/pages/item_form_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/profile/presentation/pages/help_support_page.dart';
import '../../features/profile/domain/entities/user_profile.dart';
import '../../features/export/presentation/pages/export_page.dart';
import '../../features/items/presentation/pages/deleted_items_page.dart';
import '../../features/bluetooth/presentation/pages/bluetooth_page.dart';
import '../../features/bluetooth/presentation/pages/bluetooth_search_page.dart';
import '../../features/bluetooth/presentation/pages/bluetooth_test_page.dart';
import '../../features/bluetooth/presentation/pages/paired_devices_page.dart';
import '../../features/items/domain/entities/item.dart';
import '../../features/categories/presentation/pages/manage_categories_page.dart';

/// App Router using GoRouter with shell navigation
class AppRouter {
  AppRouter._();

  static GoRouter createRouter(AuthStateNotifier authStateNotifier) {
    return GoRouter(
      initialLocation: '/',
      debugLogDiagnostics: true,
      refreshListenable: authStateNotifier,
      navigatorKey: appNavigatorKey,
      redirect: (context, state) {
        // While loading (user state not yet determined), don't redirect
        if (authStateNotifier.loading) {
          return null;
        }

        final loggedIn = authStateNotifier.loggedIn;
        final loggingIn = state.matchedLocation == LoginPage.routePath ||
            state.matchedLocation == SignupPage.routePath ||
            state.matchedLocation == ForgotPasswordPage.routePath;
        final onOnboarding = state.matchedLocation == OnboardingPage.routePath;

        // If not logged in and not on auth page, redirect to login
        if (!loggedIn && !loggingIn) {
          return LoginPage.routePath;
        }

        // If logged in and on auth page, redirect to home
        if (loggedIn && loggingIn) {
          return '/';
        }

        // If on onboarding page, allow it (user navigated there manually or from signup)
        // No automatic redirect to onboarding - it's only shown after signup

        // Handle saved redirect location
        if (authStateNotifier.shouldRedirect) {
          final redirectLocation = authStateNotifier.getRedirectLocation();
          authStateNotifier.clearRedirectLocation();
          return redirectLocation;
        }

        return null;
      },
      routes: [
        // Auth routes (no shell)
        GoRoute(
          name: LoginPage.routeName,
          path: LoginPage.routePath,
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          name: SignupPage.routeName,
          path: SignupPage.routePath,
          builder: (context, state) => const SignupPage(),
        ),
        GoRoute(
          name: ForgotPasswordPage.routeName,
          path: ForgotPasswordPage.routePath,
          builder: (context, state) => const ForgotPasswordPage(),
        ),
        GoRoute(
          name: OnboardingPage.routeName,
          path: OnboardingPage.routePath,
          builder: (context, state) => const OnboardingPage(),
        ),

        // Main app with shell navigation
        ShellRoute(
          navigatorKey: GlobalKey<NavigatorState>(),
          builder: (context, state, child) {
            // Show loading while auth state is being determined
            if (authStateNotifier.loading) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return AppShell(child: child);
          },
          routes: [
            // Items tab
            GoRoute(
              name: ItemsListPage.routeName,
              path: '/',
              builder: (context, state) => const ItemsListPage(),
              routes: [
                // ItemFormPage MUST come before ItemDetailPage to avoid
                // 'items/form' matching 'items/:id' with id='form'
                GoRoute(
                  name: ItemFormPage.routeName,
                  path: 'items/form',
                  builder: (context, state) {
                    final extra = state.extra as Map?;
                    final item = extra?['item'] as Item?;
                    return ItemFormPage(item: item);
                  },
                ),
                GoRoute(
                  name: 'ItemDetailPage',
                  path: 'items/:id',
                  builder: (context, state) {
                    final itemId = state.pathParameters['id'] ?? '';
                    final itemName = state.uri.queryParameters['name'];
                    final countStr = state.uri.queryParameters['count'];
                    final resetStr = state.uri.queryParameters['resetTime'];
                    final initialCountStr = state.uri.queryParameters['initialCount'];
                    final goalStr = state.uri.queryParameters['goal'];
                    final incrementByStr = state.uri.queryParameters['incrementBy'];
                    final reminderTypeStr = state.uri.queryParameters['reminderType'];
                    final reminderValueStr = state.uri.queryParameters['reminderValue'];
                    final resetNumberStr = state.uri.queryParameters['resetNumber'];
                    final lastUpdatedStr = state.uri.queryParameters['lastUpdated'];

                    // Parse reminder type from string
                    ReminderType? reminderType;
                    if (reminderTypeStr != null) {
                      reminderType = ReminderType.values.firstWhere(
                        (e) => e.name == reminderTypeStr,
                        orElse: () => ReminderType.none,
                      );
                    }

                    return ItemDetailPage(
                      itemId: itemId,
                      itemName: itemName,
                      currentCount: countStr != null ? int.tryParse(countStr) : null,
                      lastResetTime: resetStr != null ? DateTime.tryParse(resetStr) : null,
                      initialCount: initialCountStr != null ? int.tryParse(initialCountStr) : null,
                      goal: goalStr != null ? int.tryParse(goalStr) : null,
                      incrementBy: incrementByStr != null ? int.tryParse(incrementByStr) : null,
                      reminderType: reminderType,
                      reminderValue: reminderValueStr != null ? int.tryParse(reminderValueStr) : null,
                      resetNumber: resetNumberStr != null ? int.tryParse(resetNumberStr) : null,
                      lastUpdated: lastUpdatedStr != null ? DateTime.tryParse(lastUpdatedStr) : null,
                    );
                  },
                ),
              ],
            ),

            // Bluetooth tab
            GoRoute(
              name: BluetoothPage.routeName,
              path: BluetoothPage.routePath,
              builder: (context, state) => const BluetoothPage(),
              routes: [
                GoRoute(
                  name: BluetoothSearchPage.routeName,
                  path: 'search',
                  builder: (context, state) => const BluetoothSearchPage(),
                ),
                // Temporary test route - remove after Task #18
                GoRoute(
                  name: 'BluetoothTestPage',
                  path: 'test',
                  builder: (context, state) => const BluetoothTestPage(),
                ),
              ],
            ),

            // Profile tab
            GoRoute(
              name: 'ProfilePage',
              path: '/profile',
              builder: (context, state) => const ProfilePage(),
              routes: [
                GoRoute(
                  name: ExportPage.routeName,
                  path: 'export',
                  builder: (context, state) => const ExportPage(),
                ),
                GoRoute(
                  name: DeletedItemsPage.routeName,
                  path: 'deleted-items',
                  builder: (context, state) => const DeletedItemsPage(),
                ),
                GoRoute(
                  name: EditProfilePage.routeName,
                  path: 'edit',
                  builder: (context, state) {
                    final profile = state.extra as UserProfile;
                    return EditProfilePage(profile: profile);
                  },
                ),
                GoRoute(
                  name: HelpSupportPage.routeName,
                  path: 'help',
                  builder: (context, state) => const HelpSupportPage(),
                ),
                GoRoute(
                  name: ManageCategoriesPage.routeName,
                  path: 'categories',
                  builder: (context, state) => const ManageCategoriesPage(),
                ),
                GoRoute(
                  name: PairedDevicesPage.routeName,
                  path: PairedDevicesPage.routePath,
                  builder: (context, state) => const PairedDevicesPage(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Extension for safe navigation
extension NavigationExtensions on BuildContext {
  void safePop() {
    if (canPop()) {
      pop();
    } else {
      go('/');
    }
  }
}
