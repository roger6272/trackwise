import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

/// Global service locator instance
final sl = GetIt.instance;

/// Initialize dependency injection with Injectable
///
/// This function will be called from main.dart after Firebase initialization.
/// It sets up all dependencies using Injectable code generation.
///
/// External dependencies (Firebase, GoogleSignIn, etc.) are registered via
/// [RegisterModule] in register_module.dart.
@InjectableInit()
Future<void> configureDependencies() async {
  sl.init();
}
