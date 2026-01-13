@echo off
REM Script to run E2E tests with Firebase emulator
REM Usage: run_e2e_tests.bat

echo ========================================
echo Starting Firebase Emulator...
echo ========================================

cd ..\..\..\..\firebase

REM Check if emulator is already running
netstat -ano | findstr :8080 > nul
if %errorlevel% == 0 (
    echo Emulator is already running on port 8080
    echo Skipping emulator start
) else (
    echo Starting emulator...
    start "Firebase Emulator" cmd /k firebase emulators:start
    echo Waiting 15 seconds for emulator to start...
    timeout /t 15 /nobreak
)

echo.
echo ========================================
echo Running E2E Tests...
echo ========================================

cd ..\test\features\items\e2e
flutter test items_e2e_test.dart --reporter=expanded

echo.
echo ========================================
echo E2E Tests Complete!
echo ========================================
echo.
echo To stop the emulator, close the Firebase Emulator window
echo or run: taskkill /IM java.exe /F
echo.

pause
