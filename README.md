# 🛡️ Aegis AppLock

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Kotlin](https://img.shields.io/badge/Kotlin-Android-7F52FF?logo=kotlin)](https://kotlinlang.org)
[![Security](https://img.shields.io/badge/Security-SHA--256%20Salted-10B981)](#-security--cryptographic-model)
[![Tests](https://img.shields.io/badge/Tests-13%20Passed-brightgreen)](#-testing--quality-assurance)
[![License](https://img.shields.io/badge/License-Proprietary-red)](#)

**Aegis AppLock** is a high-performance, battery-efficient application locker for Android built with Flutter and Native Kotlin. It provides hardware-accelerated security, zero-lag app interception, anti-uninstall protection via Android Device Administrator, biometrics, and a multi-tier progressive lockout state machine.

---

## 🌟 Key Features

### ⚡ 1. Ultra-Fast Interception Engine (<100ms)
- **100ms High-Frequency Polling**: Background `AppLockService` checks foreground window usage events in real-time with an 800ms sliding query window.
- **Zero-Latency Window Launch**: `LockScreenActivity` eliminates window animations (`setWindowAnimations(0)` and `overridePendingTransition(0, 0)`) for 0ms transition latency.
- **Optimized UI Performance**: App icons are downscaled to 48x48 px PNGs and cached in-memory, preventing Android Choreographer frame drops.

### 🛑 2. Anti-Uninstall Tamper Protection (Password to Delete)
- **Android Device Administrator**: Registered via `DevicePolicyManager`. When active, the Android OS disables and greys out the "Uninstall" button in the device launcher and system app info screen.
- **System Settings & Uninstaller Interception**: Automatically locks `com.android.packageinstaller`, `com.google.android.packageinstaller`, and `com.android.settings` when protection is active.
- **PIN/Password Guarded Deactivation**: Disabling Anti-Uninstall in Settings requires mandatory PIN/Pattern verification before `deactivateDeviceAdmin()` is permitted.

### ❓ 3. Strict 2 Security Questions Emergency Recovery
Recovery is strictly restricted to two designated questions with no unauthorized alterations:
1. **"What was the name of your first school?"**
2. **"What is your best friend's name?"**
- Stored using cryptographic SHA-256 hashes with unique 16-byte random salts.
- Case-insensitive and whitespace-normalized answer verification.

### 🔐 4. Multi-Factor Authentication
- **4-Digit Numeric PIN**: Custom high-contrast, responsive PIN keypad.
- **3x3 Dot Gesture Pattern**: Smooth vector-rendered gesture pad with haptic feedback.
- **Hardware Biometrics**: Fingerprint & Face Unlock via Android BiometricPrompt.

### ⏳ 5. Multi-Tier Progressive Lockout State Machine
Protects against brute-force attacks with progressive penalties:
- **Attempts 1 – 4**: Standard verification with immediate feedback.
- **Attempt 5 (Tier 1)**: Locked for **30 seconds**.
- **Attempt 8 (Tier 2)**: Locked for **120 seconds** (+3 attempts penalty).
- **Attempt 11+ (Tier 3)**: Locked for **300 seconds** AND unlocks the **Mandatory 2 Security Questions challenge**.
- **Post-11 Attempts**: Cannot be unlocked by PIN or Pattern alone; requires answering both security questions.

### 🔄 6. Configurable Relock Policies
- **Screen Off (Default)**: Apps remain unlocked until the phone screen turns off.
- **Immediate Exit**: Re-locks instantly every time the user exits the application.
- **1-Minute Grace Period**: 60-second window before re-locking.
- **5-Minute Grace Period**: 300-second window before re-locking.

---

## 🏗️ Architecture & Technology Stack

```
┌────────────────────────────────────────────────────────┐
│                   Flutter UI Layer                     │
│  - AppLockState (ChangeNotifier & ListenableBuilder)   │
│  - SettingsScreen, LockScreen, SecurityQuestionsScreen │
│  - PinPadView, PatternPadView                          │
└───────────────────────────┬────────────────────────────┘
                            │ MethodChannel
                            │ ('com.aegis.applock/channel')
┌───────────────────────────▼────────────────────────────┐
│              Native Android Layer (Kotlin)             │
│  - MainActivity: Channel dispatcher & app discovery    │
│  - AppLockService: Foreground service (100ms engine)   │
│  - LockScreenActivity: Zero-latency native lock overlay│
│  - AegisDeviceAdminReceiver: Device Administrator guard│
│  - AppLockAccessibilityService: Accessibility fallback │
│  - LockSessionManager: Thread-safe in-memory state     │
└────────────────────────────────────────────────────────┘
```

| Layer | Technologies Used |
|---|---|
| **Frontend Framework** | Flutter 3.x (Dart 3.x) |
| **Native Android** | Kotlin 1.9+, Android SDK 34/35/36 |
| **Cryptography** | SHA-256 (`crypto` package) with 16-byte cryptographically secure random salts |
| **Local Storage** | `FlutterSecureStorage` (AES hardware keystore) + `SharedPreferences` (fallback) |
| **Inter-Process Comm** | Android `MethodChannel` (`com.aegis.applock/channel`) |
| **System APIs** | `UsageStatsManager`, `DevicePolicyManager`, `AccessibilityService`, `BiometricPrompt` |

---

## 📱 Required Android Permissions

Aegis AppLock requires the following permissions to operate reliably:

1. **Usage Access (`android.permission.PACKAGE_USAGE_STATS`)**:
   Enables Aegis to detect which app is currently running in the foreground.
2. **Display Over Other Apps (`android.permission.SYSTEM_ALERT_WINDOW`)**:
   Allows Aegis to show the lock screen instantly over protected applications.
3. **Accessibility Service (`android.permission.BIND_ACCESSIBILITY_SERVICE`)**:
   Provides an ultra-fast event stream for window state changes as a companion to UsageStats.
4. **Device Administrator (`android.permission.BIND_DEVICE_ADMIN`)**:
   Grants Anti-Uninstall policy enforcement to prevent unauthorized removal without credentials.
5. **Foreground Service & Boot (`FOREGROUND_SERVICE`, `RECEIVE_BOOT_COMPLETED`)**:
   Ensures the protection service starts on phone reboot and remains persistent without OS killing.

---

## 🚀 Build & Installation Guide

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.22.0)
- Android SDK (API Level 21 through 36)
- Java 11 or 17 (set in `JAVA_HOME`)

### 1. Build Release APK for Mobile Devices

Open PowerShell in the project directory:

```powershell
# Set JAVA_HOME to your JDK / Android Studio JBR
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"

# Build signed release APK
flutter build apk --release
```

The compiled release APK will be located at:
```
build/app/outputs/flutter-apk/app-release.apk
```

> **Note**: A split-per-ABI APK (reducing file size for specific architectures like arm64-v8a) can also be generated:
> ```powershell
> flutter build apk --release --split-per-abi
> ```

---

### 2. Installing on a Mobile Phone

#### Option A: Direct Installation via ADB (USB Cable)
1. Enable **Developer Options** and **USB Debugging** on your phone.
2. Connect your phone via USB and run:
```powershell
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

#### Option B: Sideloading (Wireless / File Transfer)
1. Copy `app-release.apk` to your phone via USB cable, Google Drive, Telegram, or WhatsApp.
2. Open the file on your device and tap **Install**.
3. If prompted, enable **"Install unknown apps"** for your file manager.

---

### 3. OEM-Specific Setup (Important for 100% Uptime)

Different Android phone manufacturers (Xiaomi, Samsung, Oppo, Vivo, Huawei) aggressively terminate background services unless configured:

#### 🔹 Xiaomi / Redmi / POCO (MIUI / HyperOS):
- Settings > Apps > Manage Apps > **Aegis AppLock** > Enable **Autostart**.
- Battery Saver > Set to **No restrictions**.
- Lock Aegis in Recent Apps tray (tap and hold > Padlock icon).

#### 🔹 Samsung (One UI):
- Settings > Battery and device care > Battery > Background usage limits > **Never sleeping apps** > Add **Aegis AppLock**.
- Disable "Put unused apps to sleep".

#### 🔹 OnePlus / OPPO / Realme (ColorOS / OxygenOS):
- Settings > Apps > App Management > Aegis AppLock > Battery Usage > Enable **Allow background activity** and **Allow auto-launch**.

#### 🔹 Vivo (Funtouch OS):
- Settings > Battery > High background power consumption > Enable for **Aegis AppLock**.

---

## 🔒 Security & Cryptographic Model

### Credential Hashing
- Credentials (PIN, Pattern, Security Answers) are never stored in plaintext.
- Every secret is combined with a 16-byte cryptographically secure random salt generated via `Random.secure()`:
  $$\text{Hash} = \text{SHA-256}(\text{Salt} \mathbin{\Vert} \text{Credential})$$
- Even if two users choose identical PINs, their stored hashes are completely different.

### Anti-Uninstall Resistance
```
User / Intruder attempts uninstallation:
├── Via Phone Settings / Launcher:
│   └── Android OS blocks "Uninstall" button (Device Admin active)
├── Via Package Installer:
│   └── AppLockService intercepts "com.android.packageinstaller" -> displays LockScreenActivity
└── Via Aegis Settings toggle:
    └── Password dialog triggers -> requires valid PIN/Pattern -> verifies SHA-256 hash
```

---

## 🧪 Testing & Quality Assurance

The codebase includes a full suite of unit and integration tests:

```powershell
# Run all Dart unit tests
flutter test

# Run static code analysis
flutter analyze
```

### Test Coverage Highlights:
- ✅ AppItem model parsing, classification (social, sensitive, banking).
- ✅ SHA-256 cryptographic hashing consistency and salt differentiation.
- ✅ Exact multi-tier lockout escalation state machine (5, 8, 11+ attempts).
- ✅ Normalization & verification of the 2 security questions.
- ✅ Widget and state initialization tests.

---

## 📁 Project Structure

```
d:/Development/applock/
├── android/
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── kotlin/com/aegis/applock/applock/
│   │   │   │   ├── MainActivity.kt                  # Platform bridge dispatcher & app lister
│   │   │   │   ├── AppLockService.kt                # Foreground service (100ms polling loop)
│   │   │   │   ├── LockScreenActivity.kt            # Native zero-lag lock screen activity
│   │   │   │   ├── AegisDeviceAdminReceiver.kt      # Device Administrator receiver
│   │   │   │   ├── AppLockAccessibilityService.kt   # Accessibility window tracker
│   │   │   │   └── LockSessionManager.kt            # State & session manager
│   │   │   ├── res/
│   │   │   │   └── xml/device_admin_policies.xml    # Device Admin policies
│   │   │   └── AndroidManifest.xml                  # Manifest with service declarations
├── lib/
│   ├── models/
│   │   ├── app_item.dart                            # App entity model & categorization
│   │   └── security_question.dart                   # Security question model (strictly 2)
│   ├── screens/
│   │   ├── home_screen.dart                         # App dashboard & app list
│   │   ├── lock_screen.dart                         # Interactive Flutter lock screen
│   │   ├── onboarding_screen.dart                   # Setup wizard
│   │   ├── security_questions_screen.dart           # Strict 2 questions setup & recovery
│   │   └── settings_screen.dart                     # Settings & Anti-Uninstall toggle
│   ├── services/
│   │   ├── platform_bridge.dart                     # Native MethodChannel interface
│   │   └── security_service.dart                    # SHA-256 hashing & lockout logic
│   ├── state/
│   │   └── app_lock_state.dart                      # Reactive application state
│   ├── theme/
│   │   └── app_theme.dart                           # Dark cybersecurity visual theme
│   ├── widgets/
│   │   ├── pattern_pad_view.dart                    # 3x3 dot gesture view
│   │   └── pin_pad_view.dart                        # 4-digit numeric pin pad
│   └── main.dart                                    # Application entry point
├── test/
│   ├── app_item_test.dart                           # AppItem unit tests
│   ├── security_service_test.dart                   # Cryptography & lockout unit tests
│   └── widget_test.dart                             # Widget smoke test
└── README.md                                        # Documentation
```

---

## 📄 License

Copyright © 2026 Aegis Security Systems. All rights reserved.
Protected under proprietary software license. Unauthorized copying or redistribution is strictly prohibited.
