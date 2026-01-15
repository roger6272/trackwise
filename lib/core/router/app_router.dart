import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/flutter_flow/nav/nav.dart' show AppStateNotifier, appNavigatorKey;
import '../widgets/app_shell.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/items/presentation/pages/items_list_page.dart';
import '../../features/items/presentation/pages/item_detail_page.dart';
import '../../features/items/presentation/pages/item_form_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/export/presentation/pages/export_page.dart';
import '../../features/bluetooth/presentation/pages/bluetooth_page.dart';
import '../../features/bluetooth/presentation/pages/bluetooth_search_page.dart';
import '../../features/bluetooth/presentation/pages/device_management_page.dart';
import '../../features/items/domain/entities/item.dart';

/// App Router using GoRouter with shell navigation
class AppRouter {
  AppRouter._();

  static GoRouter createRouter(AppStateNotifier appStateNotifier) {
    return GoRouter(
      initialLocation: '/',
      debugLogDiagnostics: true,
      refreshListenable: appStateNotifier,
      navigatorKey: appNavigatorKey,
      redirect: (context, state) {
        // While loading (user state not yet determined), don't redirect
        if (appStateNotifier.loading) {
          return null;
        }

        final loggedIn = appStateNotifier.loggedIn;
        final loggingIn = state.matchedLocation == LoginPage.routePath ||
            state.matchedLocation == SignupPage.routePath ||
            state.matchedLocation == ForgotPasswordPage.routePath;

        // If not logged in and not on auth page, redirect to login
        if (!loggedIn && !loggingIn) {
          return LoginPage.routePath;
        }

        // If logged in and on auth page, redirect to home
        if (loggedIn && loggingIn) {
          return '/';
        }

        // Handle saved redirect location
        if (appStateNotifier.shouldRedirect) {
          final redirectLocation = appStateNotifier.getRedirectLocation();
          appStateNotifier.clearRedirectLocation();
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

        // Main app with shell navigation
        ShellRoute(
          navigatorKey: GlobalKey<NavigatorState>(),
          builder: (context, state, child) {
            // Show loading while auth state is being determined
            if (appStateNotifier.loading) {
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
                GoRoute(
                  name: 'ItemDetailPage',
                  path: 'items/:id',
                  builder: (context, state) {
                    final itemId = state.pathParameters['id'] ?? '';
                    final itemName = state.uri.queryParameters['name'];
                    final countStr = state.uri.queryParameters['count'];
                    final resetStr = state.uri.queryParameters['resetTime'];
                    return ItemDetailPage(
                      itemId: itemId,
                      itemName: itemName,
                      currentCount: countStr != null ? int.tryParse(countStr) : null,
                      lastResetTime: resetStr != null ? DateTime.tryParse(resetStr) : null,
                    );
                  },
                ),
                GoRoute(
                  name: ItemFormPage.routeName,
                  path: ItemFormPage.routePath.replaceFirst('/', ''),
                  builder: (context, state) {
                    final item = state.extra as Item?;
                    return ItemFormPage(item: item);
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
                GoRoute(
                  name: DeviceManagementPage.routeName,
                  path: 'device',
                  builder: (context, state) => const DeviceManagementPage(),
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
