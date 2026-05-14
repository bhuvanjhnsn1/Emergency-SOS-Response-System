# SOS Guardian

A high-performance Flutter application designed to interface with ESP32-C3 hardware triggers. This system facilitates an automated emergency protocol involving GPS tracking, silent SMS alerts, and direct cellular calls initiated by a physical button press.

## The Emergency Logic Chain

1. Hardware Wake: Physical button press wakes the ESP32-C3 from Deep Sleep.
2. Fast Advertise: ESP32 advertises its BLE service for 10 seconds.
3. App Handshake: The Flutter app detects the specific Service UUID and connects instantly.
4. SOS Trigger: App receives the CMD_TRIGGER_SOS command string via BLE notifications.
5. Cloud Sync: The event is immediately logged to Firebase Firestore for historical tracking.
6. GPS Lock: App captures current Latitude/Longitude with high accuracy.
7. Silent SMS Phase: App sends an automated background SMS to multiple configured guardians containing a live tracking link.
8. Call Phase: App automatically dials the primary emergency contact number.

## Features

- Real-time BLE Monitoring: Dashboard showing the connection status with the ESP32 device.
- Automated Protocol: Zero-touch emergency execution once triggered.
- Multi-Guardian Support: Notifies multiple contacts concurrently via silent SMS delivery.
- Cloud Integration: Firebase Authentication (Email/Password) and Firestore for profile and event logging.
- High-Accuracy Tracking: Precise GPS location acquisition and live tracking dashboard integration.
- Premium UI: Glassmorphic dark-theme design with state indicators and protocol timelines.
- Security: Comprehensive permission management for Bluetooth, Location, SMS, and Phone APIs.

## Hardware Specifications (ESP32-C3)

To interface correctly with this app, the ESP32 firmware must match these specifications:

| Requirement | Value |
| :--- | :--- |
| Service UUID | 4fafc201-1fb5-459e-8fcc-c5c9c331914b |
| Trigger Characteristic | beb5483e-36e1-4688-b7f5-ea07361b26a8 |
| SOS Command | CMD_TRIGGER_SOS |
| Wakeup Source | GPIO_NUM_9 (Active Low) |

## Installation & Setup

1. Dependencies: Execute `flutter pub get` to install required packages.
2. Firebase Configuration: Ensure the `google-services.json` is correctly placed and Email/Password Authentication is enabled in the Firebase Console.
3. Permissions: Navigate to the application Settings and grant all required permissions (Bluetooth, Location, SMS, Phone).
4. Configuration: Create an account and populate emergency contact details in the profile section.
5. Deployment: Execute on a physical Android device (BLE and Telephony features are not supported on emulators).

## Project Structure

- `lib/services/auth_service.dart`: Handles Firebase authentication and session management.
- `lib/services/ble_service.dart`: Handles BLE scanning, connection, and notification listening.
- `lib/services/emergency_service.dart`: Orchestrates the GPS, SMS, and Call sequence.
- `lib/services/user_service.dart`: Manages Firestore synchronization for user profiles and event history.
- `lib/screens/home_screen.dart`: The primary dashboard and monitoring interface.

---
*Built for the Emergency SOS Response System.*
