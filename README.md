# SOS Guardian 🛡️

A high-performance Flutter application designed to interface with **ESP32-C3** hardware triggers. This system facilitates an automated emergency protocol involving GPS tracking, SMS alerts, and direct cellular calls initiated by a physical button press.

## 🚀 The Emergency Logic Chain

1.  **Hardware Wake**: Physical button press wakes the ESP32-C3 from Deep Sleep.
2.  **Fast Advertise**: ESP32 advertises its BLE service for 10 seconds.
3.  **App Handshake**: The Flutter app detects the specific Service UUID and connects instantly.
4.  **SOS Trigger**: App receives the `CMD_TRIGGER_SOS` command string via BLE notifications.
5.  **GPS Lock**: App captures current Latitude/Longitude with high accuracy.
6.  **SMS Phase**: App sends an emergency SMS to the primary contact with a Google Maps link.
7.  **Call Phase**: App automatically dials the primary emergency contact number.

## 📱 Features

-   **Real-time BLE Monitoring**: Animated dashboard showing the connection status with your ESP32 device.
-   **Automated Protocol**: Zero-touch emergency execution once triggered.
-   **High-Accuracy Tracking**: Precise GPS location acquisition using the `geolocator` service.
-   **Premium UI**: Glassmorphic dark-theme design with animated pulse indicators and protocol timelines.
-   **Security**: Comprehensive permission management for Bluetooth, Location, SMS, and Phone.

## 🔧 Hardware Specifications (ESP32-C3)

To interface correctly with this app, your ESP32 firmware must match these specifications:

| Requirement | Value |
| :--- | :--- |
| **Service UUID** | `4fafc201-1fb5-459e-8fcc-c5c9c331914b` |
| **Trigger Characteristic** | `beb5483e-36e1-4688-b7f5-ea07361b26a8` |
| **SOS Command** | `CMD_TRIGGER_SOS` |
| **Wakeup Source** | `GPIO_NUM_9` (Active Low) |

## 🛠️ Installation & Setup

1.  **Dependencies**:
    ```bash
    flutter pub get
    ```
2.  **Permissions**:
    Open the app, go to **Settings**, and grant all required permissions (Bluetooth, Location, SMS, Phone).
3.  **Configuration**:
    Enter your name and your primary emergency contact's details in the Settings screen.
4.  **Deployment**:
    Run on a **physical Android device** (BLE and SMS/Call features are not supported on emulators).

## 📂 Project Structure

-   `lib/services/ble_service.dart`: Handles BLE scanning, connection, and notification listening.
-   `lib/services/emergency_service.dart`: Orchestrates the GPS → SMS → Call sequence.
-   `lib/services/location_service.dart`: Manages high-accuracy GPS coordinates.
-   `lib/widgets/pulse_button.dart`: The main animated SOS status indicator.
-   `lib/screens/home_screen.dart`: The primary dashboard and monitoring UI.

---
*Built for the Emergency SOS Response System.*
