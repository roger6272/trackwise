# Items E2E Tests

End-to-end tests for the Items feature using real Firebase emulator.

## Overview

These tests differ from integration tests by using:
- ✅ **Real Firebase Emulator** (not fake Firestore)
- ✅ **Real Authentication** (Firebase Auth emulator)
- ✅ **Real Network Conditions** (latency, concurrency)
- ✅ **Real Firestore Behavior** (transactions, atomicity)
- ✅ **Multi-Client Sync** (real-time updates)

## Prerequisites

### 1. Install Firebase CLI

```bash
npm install -g firebase-tools
```

Verify installation:
```bash
firebase --version
```

### 2. Install Java (required for Firestore emulator)

Download from: https://www.oracle.com/java/technologies/downloads/

Verify installation:
```bash
java -version
```

### 3. Initialize Firebase Emulator (if not done)

```bash
cd firebase
firebase init emulators
```

Select:
- [x] Firestore
- [x] Authentication
- [x] Emulator UI

## Running E2E Tests

### Option 1: Two Terminals (Recommended)

**Terminal 1:** Start Firebase Emulator
```bash
cd firebase
firebase emulators:start
```

Wait for message: `All emulators ready!`

**Terminal 2:** Run E2E Tests
```bash
flutter test test/features/items/e2e/items_e2e_test.dart
```

### Option 2: Background Emulator (Windows)

```bash
# Start emulator in background
cd firebase
start /B firebase emulators:start

# Wait 10 seconds for emulator to start
timeout /t 10

# Run tests
flutter test test/features/items/e2e/items_e2e_test.dart

# Stop emulator when done
taskkill /IM java.exe /F
```

### Option 3: Background Emulator (Linux/Mac)

```bash
# Start emulator in background
cd firebase
firebase emulators:start &

# Wait for emulator to start
sleep 10

# Run tests
flutter test test/features/items/e2e/items_e2e_test.dart

# Stop emulator when done
pkill -f firebase
```

## Emulator Configuration

The emulator uses the following ports (configured in `firebase/firebase.json`):

- **Firestore:** localhost:8080
- **Authentication:** localhost:9099
- **Emulator UI:** http://localhost:4000

## Test Coverage

### 1. Authentication & User Isolation (2 tests)
- ✅ Create items with authenticated user
- ✅ Only retrieve items for authenticated user

### 2. Real Firestore Behavior (3 tests)
- ✅ Persist data correctly with real Firestore
- ✅ Handle concurrent increments atomically
- ✅ Handle delete with cascading EventLog deletion

### 3. Multi-Client Real-Time Sync (3 tests)
- ✅ Sync updates across multiple BLoC instances
- ✅ Sync increments across multiple watchers
- ✅ Sync deletes across multiple watchers

### 4. Network & Error Scenarios (2 tests)
- ✅ Handle network delays gracefully
- ✅ Handle large batch operations

### 5. BLoC Optimistic Updates (1 test)
- ✅ Show optimistic update then server confirmation

**Total: 11 E2E tests**

## Troubleshooting

### Error: "Firebase emulator is not running"

**Solution:** Start the emulator first:
```bash
cd firebase
firebase emulators:start
```

### Error: "Port already in use"

**Solution:** Stop existing emulator instance:
```bash
# Windows
taskkill /IM java.exe /F

# Linux/Mac
pkill -f firebase
```

### Error: "ECONNREFUSED localhost:8080"

**Solution:**
1. Check if Firestore emulator is running: http://localhost:4000
2. Verify firebase.json has correct emulator configuration
3. Restart emulator

### Error: "Firebase already initialized"

**Solution:** This is expected and handled automatically. Ignore this message.

### Slow Test Execution

E2E tests are slower than unit/integration tests because they:
- Use real network calls
- Wait for Firestore to settle
- Test real-time sync (requires delays)

**Expected runtime:** 10-20 seconds for 11 tests

## Comparing Test Types

| Test Type | Speed | Mocking | Realism | Use Case |
|-----------|-------|---------|---------|----------|
| **Unit** | ⚡⚡⚡ Very Fast | Heavy | Low | Test logic in isolation |
| **Integration** | ⚡⚡ Fast | None (FakeFirestore) | Medium | Test stack integration |
| **E2E** | ⚡ Slow | None (Real emulator) | High | Test production-like scenarios |

## Best Practices

### 1. Run E2E Tests Before Deployment

```bash
# Start emulator
cd firebase
firebase emulators:start

# Run all tests (unit + integration + E2E)
flutter test test/features/items/
```

### 2. Clean Up Between Tests

Each test calls:
- `setUp()` - Connects to emulator, creates test user
- `clearFirestore()` - Removes all data
- `tearDown()` - Signs out, closes resources

### 3. Use Delays for Real-Time Sync

```dart
// Wait for Firestore to settle after write
await Future.delayed(Duration(milliseconds: 200));

// Wait for real-time sync across clients
await Future.delayed(Duration(milliseconds: 800));
```

### 4. Verify Both Optimistic and Server States

```dart
// Optimistic update (immediate)
expect(bloc.state, isA<ItemsLoaded>());

// Wait for server confirmation
await Future.delayed(Duration(milliseconds: 500));

// Server state
final finalState = bloc.state as ItemsLoaded;
expect(finalState.items[0].count, 1);
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: E2E Tests

on: [push, pull_request]

jobs:
  e2e:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2

      - name: Install Firebase CLI
        run: npm install -g firebase-tools

      - name: Start Firebase Emulator
        run: |
          cd firebase
          firebase emulators:start &
          sleep 10

      - name: Run E2E Tests
        run: flutter test test/features/items/e2e/

      - name: Stop Emulator
        run: pkill -f firebase
```

## Viewing Emulator Data

While emulator is running, visit:

**Emulator UI:** http://localhost:4000

You can:
- View Firestore data
- See authentication users
- Inspect real-time updates
- Clear data manually

## Next Steps

- Add E2E tests for other features (EventLog, Charts, etc.)
- Test offline scenarios
- Test network interruptions
- Test error recovery
- Performance testing under load
