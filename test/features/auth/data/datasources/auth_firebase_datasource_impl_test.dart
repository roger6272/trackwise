import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:google_sign_in/google_sign_in.dart';

import 'package:trackwise/core/error/exceptions.dart';
import 'package:trackwise/features/auth/data/datasources/auth_firebase_datasource_impl.dart';
import 'package:trackwise/features/auth/data/models/user_model.dart';

class MockFirebaseAuth extends Mock implements firebase.FirebaseAuth {}

class MockFirebaseUser extends Mock implements firebase.User {}

class MockUserCredential extends Mock implements firebase.UserCredential {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late AuthFirebaseDataSourceImpl dataSource;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockUsersCollection;
  late MockDocumentReference mockUserDoc;
  late MockDocumentSnapshot mockDocSnapshot;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockGoogleSignIn = MockGoogleSignIn();
    mockFirestore = MockFirebaseFirestore();
    mockUsersCollection = MockCollectionReference();
    mockUserDoc = MockDocumentReference();
    mockDocSnapshot = MockDocumentSnapshot();

    // Setup Firestore mock chain for _ensureUserDocument
    when(() => mockFirestore.collection('users')).thenReturn(mockUsersCollection);
    when(() => mockUsersCollection.doc(any())).thenReturn(mockUserDoc);
    when(() => mockUserDoc.get()).thenAnswer((_) async => mockDocSnapshot);
    when(() => mockDocSnapshot.exists).thenReturn(true); // User doc exists by default
    when(() => mockUserDoc.set(any())).thenAnswer((_) async {});

    dataSource = AuthFirebaseDataSourceImpl(
      firebaseAuth: mockFirebaseAuth,
      firestore: mockFirestore,
      googleSignIn: mockGoogleSignIn,
    );
  });

  MockFirebaseUser createMockFirebaseUser({
    String uid = 'user_123',
    String? email = 'test@example.com',
    String? displayName = 'Test User',
    String? photoURL = 'https://example.com/photo.jpg',
    bool emailVerified = true,
  }) {
    final mockUser = MockFirebaseUser();
    when(() => mockUser.uid).thenReturn(uid);
    when(() => mockUser.email).thenReturn(email);
    when(() => mockUser.displayName).thenReturn(displayName);
    when(() => mockUser.photoURL).thenReturn(photoURL);
    when(() => mockUser.emailVerified).thenReturn(emailVerified);
    return mockUser;
  }

  group('signInWithEmail', () {
    const testEmail = 'test@example.com';
    const testPassword = 'password123';

    test('should return UserModel when sign in is successful', () async {
      // Arrange
      final mockUser = createMockFirebaseUser();
      final mockCredential = MockUserCredential();
      when(() => mockCredential.user).thenReturn(mockUser);
      when(() => mockFirebaseAuth.signInWithEmailAndPassword(
            email: testEmail,
            password: testPassword,
          )).thenAnswer((_) async => mockCredential);

      // Act
      final result = await dataSource.signInWithEmail(testEmail, testPassword);

      // Assert
      expect(result, isA<UserModel>());
      expect(result.id, 'user_123');
      expect(result.email, testEmail);
    });

    test('should trim email before signing in', () async {
      // Arrange
      final mockUser = createMockFirebaseUser();
      final mockCredential = MockUserCredential();
      when(() => mockCredential.user).thenReturn(mockUser);
      when(() => mockFirebaseAuth.signInWithEmailAndPassword(
            email: testEmail,
            password: testPassword,
          )).thenAnswer((_) async => mockCredential);

      // Act
      await dataSource.signInWithEmail('  $testEmail  ', testPassword);

      // Assert
      verify(() => mockFirebaseAuth.signInWithEmailAndPassword(
            email: testEmail,
            password: testPassword,
          )).called(1);
    });

    test('should throw AuthException when credential user is null', () async {
      // Arrange
      final mockCredential = MockUserCredential();
      when(() => mockCredential.user).thenReturn(null);
      when(() => mockFirebaseAuth.signInWithEmailAndPassword(
            email: testEmail,
            password: testPassword,
          )).thenAnswer((_) async => mockCredential);

      // Act & Assert
      expect(
        () => dataSource.signInWithEmail(testEmail, testPassword),
        throwsA(isA<AuthException>()),
      );
    });

    test('should throw AuthException on Firebase error', () async {
      // Arrange
      when(() => mockFirebaseAuth.signInWithEmailAndPassword(
            email: testEmail,
            password: testPassword,
          )).thenThrow(firebase.FirebaseAuthException(
        code: 'wrong-password',
        message: 'Wrong password',
      ));

      // Act & Assert
      expect(
        () => dataSource.signInWithEmail(testEmail, testPassword),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('signUp', () {
    const testEmail = 'test@example.com';
    const testPassword = 'password123';

    test('should return UserModel when sign up is successful', () async {
      // Arrange
      final mockUser = createMockFirebaseUser();
      final mockCredential = MockUserCredential();
      when(() => mockCredential.user).thenReturn(mockUser);
      when(() => mockFirebaseAuth.createUserWithEmailAndPassword(
            email: testEmail,
            password: testPassword,
          )).thenAnswer((_) async => mockCredential);

      // Act
      final result = await dataSource.signUp(testEmail, testPassword);

      // Assert
      expect(result, isA<UserModel>());
      expect(result.id, 'user_123');
    });

    test('should throw AuthException when credential user is null', () async {
      // Arrange
      final mockCredential = MockUserCredential();
      when(() => mockCredential.user).thenReturn(null);
      when(() => mockFirebaseAuth.createUserWithEmailAndPassword(
            email: testEmail,
            password: testPassword,
          )).thenAnswer((_) async => mockCredential);

      // Act & Assert
      expect(
        () => dataSource.signUp(testEmail, testPassword),
        throwsA(isA<AuthException>()),
      );
    });

    test('should throw AuthException with mapped error for email-already-in-use',
        () async {
      // Arrange
      when(() => mockFirebaseAuth.createUserWithEmailAndPassword(
            email: testEmail,
            password: testPassword,
          )).thenThrow(firebase.FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'Email already in use',
      ));

      // Act & Assert
      expect(
        () => dataSource.signUp(testEmail, testPassword),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('already in use'),
          ),
        ),
      );
    });

    test('should throw AuthException with mapped error for weak-password',
        () async {
      // Arrange
      when(() => mockFirebaseAuth.createUserWithEmailAndPassword(
            email: testEmail,
            password: '123',
          )).thenThrow(firebase.FirebaseAuthException(
        code: 'weak-password',
        message: 'Weak password',
      ));

      // Act & Assert
      expect(
        () => dataSource.signUp(testEmail, '123'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('weak'),
          ),
        ),
      );
    });
  });

  group('signOut', () {
    test('should sign out from both Firebase and Google', () async {
      // Arrange
      when(() => mockGoogleSignIn.signOut())
          .thenAnswer((_) async => null);
      when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});

      // Act
      await dataSource.signOut();

      // Assert
      verify(() => mockGoogleSignIn.signOut()).called(1);
      verify(() => mockFirebaseAuth.signOut()).called(1);
    });

    test('should continue sign out even if Google sign out fails', () async {
      // Arrange - Google sign out returns a failed future that's caught by catchError
      when(() => mockGoogleSignIn.signOut())
          .thenAnswer((_) => Future.error(Exception('Google error')));
      when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});

      // Act
      await dataSource.signOut();

      // Assert - Firebase sign out should still be called
      verify(() => mockFirebaseAuth.signOut()).called(1);
    });
  });

  group('resetPassword', () {
    const testEmail = 'test@example.com';

    test('should call sendPasswordResetEmail with trimmed email', () async {
      // Arrange
      when(() => mockFirebaseAuth.sendPasswordResetEmail(email: testEmail))
          .thenAnswer((_) async {});

      // Act
      await dataSource.resetPassword('  $testEmail  ');

      // Assert
      verify(() => mockFirebaseAuth.sendPasswordResetEmail(email: testEmail))
          .called(1);
    });

    test('should throw AuthException on Firebase error', () async {
      // Arrange
      when(() => mockFirebaseAuth.sendPasswordResetEmail(email: testEmail))
          .thenThrow(firebase.FirebaseAuthException(
        code: 'user-not-found',
        message: 'User not found',
      ));

      // Act & Assert
      expect(
        () => dataSource.resetPassword(testEmail),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('No account found'),
          ),
        ),
      );
    });
  });

  group('currentUser', () {
    test('should return UserModel when user is logged in', () {
      // Arrange
      final mockUser = createMockFirebaseUser();
      when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);

      // Act
      final result = dataSource.currentUser;

      // Assert
      expect(result, isA<UserModel>());
      expect(result?.id, 'user_123');
    });

    test('should return null when no user is logged in', () {
      // Arrange
      when(() => mockFirebaseAuth.currentUser).thenReturn(null);

      // Act
      final result = dataSource.currentUser;

      // Assert
      expect(result, isNull);
    });
  });

  group('watchAuthState', () {
    test('should emit UserModel when user signs in', () {
      // Arrange
      final mockUser = createMockFirebaseUser();
      when(() => mockFirebaseAuth.authStateChanges())
          .thenAnswer((_) => Stream.value(mockUser));

      // Act
      final result = dataSource.watchAuthState();

      // Assert
      expect(result, emits(isA<UserModel>()));
    });

    test('should emit null when user signs out', () {
      // Arrange
      when(() => mockFirebaseAuth.authStateChanges())
          .thenAnswer((_) => Stream.value(null));

      // Act
      final result = dataSource.watchAuthState();

      // Assert
      expect(result, emits(isNull));
    });

    test('should emit multiple auth state changes', () {
      // Arrange
      final mockUser = createMockFirebaseUser();
      when(() => mockFirebaseAuth.authStateChanges()).thenAnswer(
        (_) => Stream.fromIterable([null, mockUser, null]),
      );

      // Act
      final result = dataSource.watchAuthState();

      // Assert
      expect(
        result,
        emitsInOrder([isNull, isA<UserModel>(), isNull]),
      );
    });
  });

  group('Firebase error mapping', () {
    const testEmail = 'test@example.com';
    const testPassword = 'password123';

    final errorMappings = {
      'invalid-email': 'invalid',
      'user-disabled': 'disabled',
      'user-not-found': 'No account found',
      'wrong-password': 'Incorrect password',
      'INVALID_LOGIN_CREDENTIALS': 'Invalid email or password',
      'invalid-credential': 'Invalid email or password',
      'too-many-requests': 'Too many attempts',
      'operation-not-allowed': 'not enabled',
      'requires-recent-login': 'sign in again',
    };

    for (final entry in errorMappings.entries) {
      test('should map ${entry.key} to user-friendly message', () async {
        // Arrange
        when(() => mockFirebaseAuth.signInWithEmailAndPassword(
              email: testEmail,
              password: testPassword,
            )).thenThrow(firebase.FirebaseAuthException(
          code: entry.key,
          message: 'Firebase error',
        ));

        // Act & Assert
        expect(
          () => dataSource.signInWithEmail(testEmail, testPassword),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message.toLowerCase(),
              'message',
              contains(entry.value.toLowerCase()),
            ),
          ),
        );
      });
    }
  });
}
