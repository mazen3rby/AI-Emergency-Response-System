# Mobile Emergency Module — Quick Run Guide

## Prerequisites
- Flutter SDK on `PATH` (verify with `flutter --version`).
- Android SDK platform-tools (`adb`) and emulator on `PATH`, or `ANDROID_HOME` configured.
- Emulator AVD: `Medium_Phone_API_37.0` (the old `Pixel_6` AVD crashes with `Failed to protect CE key for user 0`; `Pixel_API_34` has a missing kernel file).

## Commands
```powershell
cd <repo-root>
flutter pub get
flutter analyze      # expect: No issues found!
flutter test         # expect: 11/11 passed
flutter devices
flutter run -d <device-id>
```

## Emulator
```powershell
$emu = if ($env:ANDROID_HOME) { Join-Path $env:ANDROID_HOME 'emulator\emulator.exe' } else { 'emulator' }
& $emu -avd Medium_Phone_API_37.0 -netdelay none -netspeed full
# wait until this prints 1 (requires adb on PATH):
& adb shell getprop sys.boot_completed
```

## Safe GPS checks (mock only)
On this AVD `adb emu geo fix` did not override the Google location provider. Use the test provider instead (verified working):

```powershell
$adb = 'adb'  # requires adb on PATH
& $adb shell pm grant com.example.emergency_help android.permission.ACCESS_FINE_LOCATION
& $adb shell appops set 2000 android:mock_location allow
& $adb shell cmd location providers add-test-provider gps
& $adb shell cmd location providers set-test-provider-enabled gps true

& $adb shell cmd location providers set-test-provider-location gps --location 29.85,31.30 --accuracy 5  # Helwan
& $adb shell cmd location providers set-test-provider-location gps --location 29.96,31.28 --accuracy 5  # Maadi
& $adb shell cmd location providers set-test-provider-location gps --location 30.02,31.19 --accuracy 5  # Giza
& $adb shell cmd location providers set-test-provider-location gps --location 29.93,30.95 --accuracy 5  # 6th of October
& $adb shell cmd location providers set-test-provider-location gps --location 31.20,29.95 --accuracy 5  # Alexandria
```

Watch the result with:
```powershell
& $adb logcat | Select-String 'Nabd Home|Nabd address|Nabd SOS|Nabd GPS|Nabd history'
```

Never place a real call or send a real SMS during tests. The app only opens composers; verify the snackbar text instead.

See `MOBILE_EMERGENCY_MODULE_HANDOVER.md` for the full audit, limitations and evidence.
