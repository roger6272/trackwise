import 'dart:async';
import 'dart:ui';

import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injection.dart' as di;
import 'core/state/app_ui_state.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'features/bluetooth/presentation/bloc/bluetooth_state.dart';
import 'features/bluetooth/presentation/widgets/device_setup_dialog.dart';
import 'features/bluetooth/presentation/widgets/sync_conflict_dialog.dart';
import 'features/bluetooth/presentation/widgets/wrong_account_dialog.dart';
import 'features/profile/presentation/bloc/profile_bloc.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'core/firebase/firebase_config.dart';
import 'core/theme/app_theme.dart';

import 'core/di/injection.dart';
import 'core/auth/auth_state_notifier.dart';
import 'core/router/app_router.dart';

void main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    GoRouter.optionURLReflectsImperativeAPIs = true;
    usePathUrlStrategy();

    // Disable Google Fonts runtime fetching to prevent error spam
    // Fonts will be loaded from cache if available, otherwise system fonts are used
    GoogleFonts.config.allowRuntimeFetching = false;

    await initFirebase();

    // Initialize Crashlytics
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    // Catch errors that happen outside of the Flutter framework
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Initialize Clean Architecture Dependency Injection
    await configureDependencies();

    await AppTheme.initialize();

    // Initialize AppUiState
    final appUiState = di.sl<AppUiState>();
    await appUiState.initialize();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appUiState),
          // Clean Architecture BLoCs
          BlocProvider<BluetoothBloc>(
            create: (_) => di.sl<BluetoothBloc>(),
          ),
          BlocProvider<ProfileBloc>(
            create: (_) => di.sl<ProfileBloc>(),
          ),
          BlocProvider<AuthBloc>(
            create: (_) => di.sl<AuthBloc>()..add(const CheckAuthStatusEvent()),
          ),
        ],
        child: MyApp(),
      ),
    );
  }, (error, stack) {
    // Catch any errors that escape the zone
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class MyAppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = AppTheme.themeMode;

  late AuthStateNotifier _authStateNotifier;
  late GoRouter _router;
  StreamSubscription? _authBlocSubscription;

  String getRoute([RouteMatch? routeMatch]) {
    final RouteMatch lastMatch =
        routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : _router.routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }

  List<String> getRouteStack() =>
      _router.routerDelegate.currentConfiguration.matches
          .map((e) => getRoute(e))
          .toList();

  @override
  void initState() {
    super.initState();

    _authStateNotifier = AuthStateNotifier.instance;
    _router = AppRouter.createRouter(_authStateNotifier);

    // Listen to AuthBloc and update AuthStateNotifier
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authBloc = context.read<AuthBloc>();
      _authBlocSubscription = authBloc.stream.listen(_onAuthStateChanged);
      // Also check current state immediately
      _onAuthStateChanged(authBloc.state);
    });

    Future.delayed(
      Duration(milliseconds: 1000),
      () => _authStateNotifier.stopShowingSplashImage(),
    );
  }

  void _onAuthStateChanged(AuthState state) {
    debugPrint('🔐 main._onAuthStateChanged: state=${state.runtimeType}');
    if (state is Authenticated) {
      debugPrint('🔐 main: Authenticated user=${state.user.id}, onboardingCompleted=${state.user.onboardingCompleted}');
      _authStateNotifier.updateAuthState(
        uid: state.user.id,
        isLoggedIn: true,
        onboardingCompleted: state.user.onboardingCompleted,
      );
    } else if (state is Unauthenticated) {
      _authStateNotifier.updateAuthState(
        uid: null,
        isLoggedIn: false,
      );
    } else if (state is AuthError) {
      _authStateNotifier.updateAuthState(
        uid: null,
        isLoggedIn: false,
      );
    }
    // AuthInitial and AuthLoading - don't update yet, wait for final state
  }

  @override
  void dispose() {
    _authBlocSubscription?.cancel();
    super.dispose();
  }

  void setThemeMode(ThemeMode mode) => setState(() {
        _themeMode = mode;
        AppTheme.saveThemeMode(mode);
      });

  @override
  Widget build(BuildContext context) {
    return BlocListener<BluetoothBloc, BluetoothState>(
      listenWhen: (previous, current) =>
          !previous.hasConflict && current.hasConflict,
      listener: (context, state) {
        if (state.hasConflict) {
          // Show conflict dialog globally
          _showConflictDialog(context);
        }
      },
      child: BlocListener<BluetoothBloc, BluetoothState>(
        listenWhen: (previous, current) =>
            !previous.needsSetup && current.needsSetup,
        listener: (context, state) {
          if (state.needsSetup) {
            // Show setup dialog globally
            _showSetupDialog(context);
          }
        },
        child: BlocListener<BluetoothBloc, BluetoothState>(
          listenWhen: (previous, current) =>
              !previous.hasWrongAccount && current.hasWrongAccount,
          listener: (context, state) {
            if (state.hasWrongAccount) {
              // Show wrong account dialog globally
              _showWrongAccountDialog(context);
            }
          },
          child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Traxelos',
        scrollBehavior: MyAppScrollBehavior(),
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', '')],
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _themeMode,
        routerConfig: _router,
      ),
        ),
      ),
    );
  }

  void _showConflictDialog(BuildContext context) {
    // Use the router's navigator context for the dialog
    final navigatorContext = _router.routerDelegate.navigatorKey.currentContext;
    if (navigatorContext != null) {
      SyncConflictDialog.show(
        context: navigatorContext,
        onConfirm: () {
          // Pass the currently selected item from AppUiState
          final appUiState = context.read<AppUiState>();
          context.read<BluetoothBloc>().add(ConfirmSyncOverride(
            currentSelectedItemId: appUiState.activeItemId.isNotEmpty
                ? appUiState.activeItemId
                : null,
          ));
        },
        onCancel: () {
          context.read<BluetoothBloc>().add(const CancelSyncConflict());
        },
      );
    }
  }

  void _showSetupDialog(BuildContext context) {
    // Use the router's navigator context for the dialog
    final navigatorContext = _router.routerDelegate.navigatorKey.currentContext;
    if (navigatorContext != null) {
      DeviceSetupDialog.show(
        context: navigatorContext,
        onConfirm: () {
          // Pass the currently selected item from AppUiState
          final appUiState = context.read<AppUiState>();
          context.read<BluetoothBloc>().add(ConfirmDeviceSetup(
            currentSelectedItemId: appUiState.activeItemId.isNotEmpty
                ? appUiState.activeItemId
                : null,
          ));
        },
        onCancel: () {
          context.read<BluetoothBloc>().add(const CancelDeviceSetup());
        },
      );
    }
  }

  void _showWrongAccountDialog(BuildContext context) {
    // Use the router's navigator context for the dialog
    final navigatorContext = _router.routerDelegate.navigatorKey.currentContext;
    if (navigatorContext != null) {
      WrongAccountDialog.show(
        context: navigatorContext,
        onDismiss: () {
          context.read<BluetoothBloc>().add(const DismissWrongAccount());
        },
      );
    }
  }
}
