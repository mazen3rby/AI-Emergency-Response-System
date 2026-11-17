# Quick run guide — Person 2 mobile module

## Prerequisites
- Flutter: `C:\flutter\bin\flutter.bat`
- Android SDK / adb: `C:\Users\hp\AppData\Local\Android\Sdk\platform-tools\adb.exe`
- Emulator AVD: `Medium_Phone_API_37.0` (the old `Pixel_6` AVD crashes with `Failed to protect CE key for user 0`; `Pixel_API_34` has a missing kernel file).

## Commands
```powershell
cd C:\Users\hp\Downloads\AI-Emergency-Response-System-main
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat analyze      # expect: No issues found!
C:\flutter\bin\flutter.bat test         # expect: 11/11 passed
C:\flutter\bin\flutter.bat devices
C:\flutter\bin\flutter.bat run -d <device-id>
```

## Emulator
```powershell
$emu = 'C:\Users\hp\AppData\Local\Android\Sdk\emulator\emulator.exe'
& $emu -avd Medium_Phone_API_37.0 -netdelay none -netspeed full
# wait until this prints 1:
& 'C:\Users\hp\AppData\Local\Android\Sdk\platform-tools\adb.exe' shell getprop sys.boot_completed
```

## Safe GPS checks (mock only)
On this AVD `adb emu geo fix` did not override the Google location provider. Use the test provider instead (verified working):

```powershell
$adb = 'C:\Users\hp\AppData\Local\Android\Sdk\platform-tools\adb.exe'
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

See `PERSON2_HANDOVER.md` for the full audit, limitations and evidence.
