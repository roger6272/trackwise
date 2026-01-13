import 'package:trackwise/features/auth/domain/entities/user.dart';
import 'package:trackwise/features/auth/data/models/user_model.dart';

/// Test user with all fields populated.
const testUser = User(
  id: 'user_123',
  email: 'test@example.com',
  displayName: 'Test User',
  photoUrl: 'https://example.com/photo.jpg',
  emailVerified: true,
);

/// Test user with minimal fields.
const testUserMinimal = User(
  id: 'user_456',
  email: 'minimal@example.com',
);

/// Test user for Google sign-in.
const testGoogleUser = User(
  id: 'google_user_123',
  email: 'google@example.com',
  displayName: 'Google User',
  photoUrl: 'https://googleusercontent.com/photo.jpg',
  emailVerified: true,
);

/// Test user for Apple sign-in.
const testAppleUser = User(
  id: 'apple_user_123',
  email: 'apple@example.com',
  displayName: 'Apple User',
  emailVerified: true,
);

/// Test user model with all fields populated.
const testUserModel = UserModel(
  id: 'user_123',
  email: 'test@example.com',
  displayName: 'Test User',
  photoUrl: 'https://example.com/photo.jpg',
  emailVerified: true,
);

/// Test user model with minimal fields.
const testUserModelMinimal = UserModel(
  id: 'user_456',
  email: 'minimal@example.com',
);

/// Test credentials.
const testEmail = 'test@example.com';
const testPassword = 'password123';
const testInvalidEmail = 'invalid-email';
const testWeakPassword = '123';
