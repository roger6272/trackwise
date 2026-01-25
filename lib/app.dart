import 'package:flutter/material.dart';

/// Root application widget following Clean Architecture principles.
///
/// This widget will be configured with:
/// - Theme configuration (from core/theme/)
/// - Routing (using go_router)
/// - BLoC providers (using flutter_bloc)
/// - Dependency injection (using GetIt)
///
/// TODO: Implement full app configuration in Task 002-004
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Traxogic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const Placeholder(
        child: Center(
          child: Text('Clean Architecture Migration in Progress'),
        ),
      ),
    );
  }
}
