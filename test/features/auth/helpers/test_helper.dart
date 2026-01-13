import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';

import 'package:trackwise/features/auth/domain/repositories/auth_repository.dart';
import 'package:trackwise/features/auth/domain/usecases/sign_in_with_email_usecase.dart';
import 'package:trackwise/features/auth/domain/usecases/sign_in_with_google_usecase.dart';
import 'package:trackwise/features/auth/domain/usecases/sign_in_with_apple_usecase.dart';
import 'package:trackwise/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:trackwise/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:trackwise/features/auth/domain/usecases/reset_password_usecase.dart';
import 'package:trackwise/features/auth/domain/usecases/watch_auth_state_usecase.dart';
import 'package:trackwise/features/auth/data/datasources/auth_firebase_datasource.dart';

// Domain mocks
class MockAuthRepository extends Mock implements AuthRepository {}

class MockSignInWithEmailUseCase extends Mock implements SignInWithEmailUseCase {}

class MockSignInWithGoogleUseCase extends Mock implements SignInWithGoogleUseCase {}

class MockSignInWithAppleUseCase extends Mock implements SignInWithAppleUseCase {}

class MockSignUpUseCase extends Mock implements SignUpUseCase {}

class MockSignOutUseCase extends Mock implements SignOutUseCase {}

class MockResetPasswordUseCase extends Mock implements ResetPasswordUseCase {}

class MockWatchAuthStateUseCase extends Mock implements WatchAuthStateUseCase {}

// Data mocks
class MockAuthFirebaseDataSource extends Mock implements AuthFirebaseDataSource {}

class MockFirebaseAuth extends Mock implements firebase_auth.FirebaseAuth {}

class MockFirebaseUser extends Mock implements firebase_auth.User {}

class MockUserCredential extends Mock implements firebase_auth.UserCredential {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockGoogleSignInAuthentication extends Mock implements GoogleSignInAuthentication {}
