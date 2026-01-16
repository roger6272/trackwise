import 'dart:async';
import 'dart:ui';

import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injection.dart' as di;
import 'core/state/app_ui_state.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'features/bluetooth/presentation/bloc/bluetooth_state.dart';
import 'features/profile/presentation/bloc/profile_bloc.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'auth/firebase_auth/firebase_user_provider.dart';
import 'auth/firebase_auth/auth_util.dart';

import 'backend/firebase/firebase_config.dart';
import 'core/theme/app_theme.dart';
import 'app_state.dart';

// Clean Architecture
import 'core/di/injection.dart';
import 'core/auth/auth_state_notifier.dart';
import 'core/router/app_router.dart';

void main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    GoRouter.optionURLReflectsImperativeAPIs = true;
    usePathUrlStrategy();

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

    final appState = FFAppState(); // Initialize FFAppState
    await appState.initializePersistedState();

    // Initialize AppUiState
    final appUiState = di.sl<AppUiState>();
    await appUiState.initialize();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appState),
          ChangeNotifierProvider.value(value: appUiState),
          // Clean Architecture BLoCs
          BlocProvider<BluetoothBloc>(
            create: (_) => di.sl<BluetoothBloc>(),
          ),
          BlocProvider<ProfileBloc>(
            create: (_) => di.sl<ProfileBloc>(),
          ),
          BlocProvider<AuthBloc>(
            create: (_) => di.sl<AuthBloc>(),
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
  // This widget is the root of your application.
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
  late Stream<BaseAuthUser> userStream;

  final authUserSub = authenticatedUserStream.listen((_) {});

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
    userStream = trackwiseFirebaseUserStream()
      ..listen((user) {
        _authStateNotifier.update(user);
      });
    jwtTokenStream.listen((_) {});
    Future.delayed(
      Duration(milliseconds: 1000),
      () => _authStateNotifier.stopShowingSplashImage(),
    );
  }

  @override
  void dispose() {
    authUserSub.cancel();
    super.dispose();
  }

  void setThemeMode(ThemeMode mode) => setState(() {
        _themeMode = mode;
        AppTheme.saveThemeMode(mode);
      });

  @override
  Widget build(BuildContext context) {
    return BlocListener<BluetoothBloc, BluetoothState>(
      listener: (context, state) {
        // Sync BluetoothBloc connection state to FFAppState for FF widgets
        final ffAppState = context.read<FFAppState>();
        if (ffAppState.deviceConnected != state.isConnected) {
          ffAppState.deviceConnected = state.isConnected;
        }
      },
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Trackwise',
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
    );
  }
}
