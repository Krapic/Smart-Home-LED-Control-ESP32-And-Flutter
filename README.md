<p align="center">
  <img src="https://img.shields.io/badge/ESP32-Firmware-blue?style=for-the-badge&logo=espressif&logoColor=white" alt="ESP32"/>
  <img src="https://img.shields.io/badge/Flutter-App-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/MQTT-Protocol-660066?style=for-the-badge&logo=eclipsemosquitto&logoColor=white" alt="MQTT"/>
  <img src="https://img.shields.io/badge/BLE-Provisioning-0082FC?style=for-the-badge&logo=bluetooth&logoColor=white" alt="BLE"/>
  <img src="https://img.shields.io/badge/PlatformIO-Build-FF6600?style=for-the-badge&logo=platformio&logoColor=white" alt="PlatformIO"/>
</p>

<h1 align="center">Smart Home LED Control</h1>
<h3 align="center">ESP32 & Flutter IoT Lighting System</h3>

<p align="center">
  <i>A complete IoT smart home lighting solution combining an ESP32 microcontroller with a Flutter mobile app. Features BLE provisioning for zero-config setup, MQTT for real-time remote control, environmental sensor monitoring, and intelligent automatic lighting based on motion and ambient light detection.</i>
</p>

---

<p align="center">
  <a href="#-key-features">Features</a>&nbsp;&nbsp;|&nbsp;&nbsp;
  <a href="#-system-architecture">Architecture</a>&nbsp;&nbsp;|&nbsp;&nbsp;
  <a href="#-hardware-requirements">Hardware</a>&nbsp;&nbsp;|&nbsp;&nbsp;
  <a href="#-getting-started">Getting Started</a>&nbsp;&nbsp;|&nbsp;&nbsp;
  <a href="#-mqtt-protocol">MQTT Protocol</a>&nbsp;&nbsp;|&nbsp;&nbsp;
  <a href="#-ble-provisioning">BLE Provisioning</a>&nbsp;&nbsp;|&nbsp;&nbsp;
  <a href="#-flutter-app">Flutter App</a>
</p>

---

## Key Features

<table>
<tr>
<td width="50%">

### ESP32 Firmware
- **Dual LED Control** -- Independent on/off and brightness (0-255) for two LED channels via PWM
- **Automatic Mode** -- LEDs activate when motion is detected in low-light conditions (< 30 lux)
- **4 Environmental Sensors** -- BH1750 (light), BME280 (temperature, humidity, pressure), PIR (motion)
- **BLE Provisioning** -- Zero-config device setup via Bluetooth Low Energy
- **MQTT Integration** -- Real-time bidirectional control and sensor data streaming
- **Persistent Config** -- All settings stored in ESP32 Non-Volatile Storage (NVS)
- **Auto-Reconnect** -- Automatic WiFi and MQTT reconnection with retry logic

</td>
<td width="50%">

### Flutter Mobile App
- **Device Discovery** -- Automatic BLE scanning for SmartLED devices
- **4-Step Setup Wizard** -- Guided device provisioning (Scan, WiFi, MQTT, Verify)
- **Real-Time Dashboard** -- Live sensor readings updated every 5 seconds
- **Independent LED Control** -- Separate brightness sliders and toggles per LED
- **Mode Switching** -- Toggle between automatic and manual control
- **Quick Presets** -- One-tap brightness presets (0%, 25%, 50%, 100%)
- **Motion Indicator** -- Animated visual feedback for motion detection
- **Dark Theme UI** -- Material 3 design with an eye-friendly dark color scheme

</td>
</tr>
</table>

---

## System Architecture

```
                                    SYSTEM OVERVIEW
 ====================================================================================

   FLUTTER APP (Android/iOS)                         ESP32 MICROCONTROLLER
  +---------------------------+                   +---------------------------+
  |                          |   BLE (Setup)      |                           |
  |   +-------------------+  | =================> |  +---------------------+  |
  |   | Setup Wizard      |  |  WiFi SSID/Pass    |  | BLE GATT Server     |  |
  |   | (4-Step Stepper)  |  |  MQTT Broker/Port  |  | Service: 1234...abc |  |
  |   +-------------------+  |  Device ID         |  +---------------------+  |
  |                          |                    |            |              |
  |   +-------------------+  |   MQTT (Control)   |            v              |
  |   | Control Dashboard |  | <=================>|  +---------------------+  |
  |   |                   |  |  LED Commands      |  | WiFi + MQTT Client  |  |
  |   | - LED Brightness  |  |  Sensor Data       |  +---------------------+  |
  |   | - Sensor Readings |  |  Status Updates    |            |              |
  |   | - Mode Toggle     |  |                    |            v              |
  |   | - Motion Status   |  |                    |  +---------------------+  |
  |   +-------------------+  |                    |  | Hardware Control    |  |
  |                          |                    |  |                     |  |
  |   +-------------------+  |                    |  | LED1 (GPIO25) PWM   |  |
  |   | State Management  |  |                    |  | LED2 (GPIO26) PWM   |  |
  |   | (Provider)        |  |                    |  | PIR  (GPIO27)       |  |
  |   |                   |  |                    |  | BH1750  (I2C)       |  |
  |   | - BleService      |  |                    |  | BME280  (I2C)       |  |
  |   | - MqttService     |  |                    |  +---------------------+  |
  |   | - DeviceState     |  |                    |                           |
  |   +-------------------+  |                    +---------------------------+
  +---------------------------+
                                        |
                                        v
                               +-----------------+
                               |   MQTT Broker   |
                               | (e.g. Mosquitto)|
                               +-----------------+
```

### Communication Flow

```
  SETUP PHASE (One-time, via BLE)         CONTROL PHASE (Ongoing, via MQTT)
  ================================         ===================================

  App                     ESP32            App                 Broker          ESP32
   |                        |               |                    |               |
   |-- BLE Scan ----------->|               |                    |               |
   |<- Advertise "SmartLED" |               |--- Connect ------->|<-- Connect ---|
   |-- Connect ------------>|               |                    |               |
   |-- Write WiFi SSID ---->|               |                    |-- Sensors --->|
   |-- Write WiFi Pass ---->|               |<-- Sensor Data ----|  (every 5s)   |
   |-- Write MQTT Broker -->|               |                    |               |
   |-- Write MQTT Port ---->|               |--- LED Command --->|               |
   |-- CMD: "CONNECT" ----->|               |                    |-- LED Set --->|
   |                        |-- WiFi ------>|                    |               |
   |                        |-- MQTT ------>|                    |<- LED Status -|
   |<- Status Notify -------|               |                    |               |
   |-- Disconnect --------->|               |                    |               |
```

---

## Hardware Requirements

### Components

| Component | Description | Interface | Notes |
|:----------|:------------|:----------|:------|
| **ESP32 DevKit** | Main microcontroller | -- | Any ESP32 development board |
| **BH1750** | Ambient light sensor | I2C (SDA/SCL) | Auto-detects address `0x23` or `0x5C` |
| **BME280** | Temperature, humidity, pressure | I2C (SDA/SCL) | Auto-detects address `0x76` or `0x77` |
| **PIR Sensor** | Passive infrared motion detector | Digital GPIO | HC-SR501 or similar |
| **LED x2** | Controlled light sources | PWM GPIO | Any standard LEDs with resistors, or LED strips via MOSFET |
| **Resistors** | Current limiting for LEDs | -- | Value depends on LED specifications |

### Wiring Diagram

```
                         ESP32 DevKit
                     +------------------+
                     |                  |
    LED1 ----[R]---- | GPIO25     GPIO21| ---- SDA (BH1750 + BME280)
    LED2 ----[R]---- | GPIO26     GPIO22| ---- SCL (BH1750 + BME280)
    PIR  ----------- | GPIO27           |
                     |            3V3   | ---- VCC (Sensors)
                     |            GND   | ---- GND (All)
                     |                  |
                     +------------------+
```

### Pin Configuration

```c
// LED Control (PWM)
#define PIN_LED1        25      // PWM Channel 0
#define PIN_LED2        26      // PWM Channel 1

// Sensors
#define PIN_PIR         27      // Motion detection (digital input)
#define SDA_PIN         21      // I2C Data  (BH1750 + BME280)
#define SCL_PIN         22      // I2C Clock (BH1750 + BME280)

// PWM Settings
#define PWM_FREQ        5000    // 5 kHz switching frequency
#define PWM_RESOLUTION  8       // 8-bit (0-255 brightness levels)
```

---

## Getting Started

### Prerequisites

| Tool | Purpose | Installation |
|:-----|:--------|:-------------|
| **PlatformIO** | ESP32 firmware build & upload | [platformio.org](https://platformio.org/install) |
| **Flutter SDK** | Mobile app development (3.0+) | [flutter.dev](https://docs.flutter.dev/get-started/install) |
| **MQTT Broker** | Message routing (e.g. Mosquitto) | [mosquitto.org](https://mosquitto.org/download/) |
| **Android SDK** | Android app compilation | Included with Android Studio |

### 1. Flash the ESP32 Firmware

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/Smart-Home-LED-Control-ESP32-And-Flutter.git
cd Smart-Home-LED-Control-ESP32-And-Flutter

# Build and upload firmware
cd ESP32
pio run -t upload

# (Optional) Open serial monitor to verify boot
pio device monitor
```

On first boot, the ESP32 will:
1. Generate a unique Device ID from its MAC address
2. Start advertising via BLE as `SmartLED-XXXXXX`
3. Wait for provisioning from the mobile app

### 2. Set Up the MQTT Broker

```bash
# Example: Install and start Mosquitto on your local network
# Linux
sudo apt install mosquitto mosquitto-clients
sudo systemctl start mosquitto

# macOS
brew install mosquitto
brew services start mosquitto

# Windows
# Download installer from https://mosquitto.org/download/
```

> **Note:** The broker must be reachable from both the ESP32 (WiFi) and your phone (WiFi/LAN). A local Raspberry Pi or any always-on machine on the same network works well.

### 3. Build and Run the Flutter App

```bash
cd FlutterApp

# Install dependencies
flutter pub get

# Run on connected Android device
flutter run

# Or build a release APK
flutter build apk
```

### 4. Provision the Device

Once the app is running and the ESP32 is powered on:

```
Step 1  -->  Tap "Setup New Device" and scan for BLE devices
Step 2  -->  Select your "SmartLED-XXXXXX" device
Step 3  -->  Enter your WiFi credentials (SSID + Password)
Step 4  -->  Enter your MQTT broker address and port (default: 1883)
Step 5  -->  Tap "Connect" and wait for verification
   Done -->  The app transitions to the Control Dashboard
```

---

## MQTT Protocol

All MQTT communication follows the topic format:

```
smarthome/{deviceId}/{topic}
```

### Topics Reference

| Topic | Direction | QoS | Description |
|:------|:----------|:----|:------------|
| `smarthome/{id}/led/set` | App --> ESP32 | 0 | Send LED control commands |
| `smarthome/{id}/led/status` | ESP32 --> App | 0 | LED state change confirmations |
| `smarthome/{id}/sensors` | ESP32 --> App | 0 | Sensor data (published every 5s) |

### LED Control Command

Published by the app to `smarthome/{id}/led/set`:

```json
{
  "mode": "manual",
  "led1": {
    "state": "on",
    "brightness": 200
  },
  "led2": {
    "state": "off",
    "brightness": 0
  }
}
```

| Field | Type | Values | Description |
|:------|:-----|:-------|:------------|
| `mode` | string | `"manual"`, `"auto"` | Control mode |
| `led1.state` | string | `"on"`, `"off"` | LED1 power state |
| `led1.brightness` | int | `0` - `255` | LED1 brightness level |
| `led2.state` | string | `"on"`, `"off"` | LED2 power state |
| `led2.brightness` | int | `0` - `255` | LED2 brightness level |

### LED Status Response

Published by ESP32 to `smarthome/{id}/led/status`:

```json
{
  "led1": { "state": "on", "brightness": 200 },
  "led2": { "state": "off", "brightness": 0 },
  "mode": "manual"
}
```

### Sensor Data Payload

Published by ESP32 to `smarthome/{id}/sensors` every 5 seconds:

```json
{
  "lux": 482.5,
  "temperature": 23.4,
  "humidity": 55.2,
  "pressure": 1013.25,
  "motion": false,
  "led1": { "state": true, "brightness": 200 },
  "led2": { "state": false, "brightness": 0 },
  "mode": "manual"
}
```

| Field | Unit | Range | Sensor |
|:------|:-----|:------|:-------|
| `lux` | lx | 0 - 65535 | BH1750 |
| `temperature` | C | -40 to 85 | BME280 |
| `humidity` | % | 0 - 100 | BME280 |
| `pressure` | hPa | 300 - 1100 | BME280 |
| `motion` | bool | `true` / `false` | PIR |

---

## BLE Provisioning

The ESP32 exposes a GATT service for initial device configuration over Bluetooth Low Energy.

### Service & Characteristics

**Service UUID:** `12345678-1234-1234-1234-123456789abc`

| Characteristic | UUID Suffix | Properties | Description |
|:---------------|:------------|:-----------|:------------|
| WiFi SSID | `...ab1` | Read / Write | Network name |
| WiFi Password | `...ab2` | Write | Network password |
| MQTT Broker | `...ab3` | Read / Write | Broker IP or hostname |
| MQTT Port | `...ab4` | Read / Write | Broker port (default 1883) |
| Device ID | `...ab5` | Read / Write | Unique device identifier |
| Status | `...ab6` | Read / Notify | Connection status updates |
| Command | `...ab7` | Write | Control commands |

### BLE Commands

Write these strings to the Command characteristic (`...ab7`):

| Command | Action |
|:--------|:-------|
| `SAVE` | Persist current config to NVS |
| `CONNECT` | Save config and initiate WiFi + MQTT connection |
| `STATUS` | Request current connection status via Notify |
| `RESET` | Clear all stored configuration |

### Device Naming

The ESP32 advertises as `SmartLED-XXXXXX` where `XXXXXX` is derived from the first 6 hex characters of the auto-generated Device ID (based on the ESP32 eFuse MAC address).

---

## Flutter App

### App Architecture

The app follows the **Provider** pattern for state management with a clean separation of concerns:

```
lib/
 |-- main.dart                     # App entry, Provider setup, theme config
 |-- screens/
 |    |-- home_screen.dart         # Entry router (setup vs. control)
 |    |-- setup_screen.dart        # 4-step BLE provisioning wizard
 |    |-- control_screen.dart      # Main dashboard with LED + sensor UI
 |-- services/
 |    |-- ble_service.dart         # BLE device discovery & communication
 |    |-- mqtt_service.dart        # MQTT client, pub/sub, state tracking
 |    |-- device_state.dart        # Persistent config (SharedPreferences)
 |-- widgets/
 |    |-- led_control_card.dart    # LED toggle, brightness slider, presets
 |    |-- sensor_card.dart         # Individual sensor reading display
 |-- models/                       # (Reserved for future data models)
```

### Services

| Service | Responsibility | Key Methods |
|:--------|:---------------|:------------|
| **BleService** | BLE scanning, connection, characteristic R/W, status notifications | `startScan()`, `connectToDevice()`, `sendWifiCredentials()`, `sendMqttConfig()`, `sendCommand()` |
| **MqttService** | MQTT connection, subscribe to topics, publish commands, track state | `connect()`, `setLed1State()`, `setLed2Brightness()`, `setMode()`, `disconnect()` |
| **DeviceState** | Persist and load device config using SharedPreferences | `loadState()`, `saveState()`, `clearState()` |

### Screens

#### Home Screen
The app entry point. On launch it loads any saved device configuration. If a device is already configured, it auto-connects to MQTT and shows the Control Screen. Otherwise, it navigates to the Setup Screen.

#### Setup Screen -- 4-Step Wizard

| Step | Title | Description |
|:-----|:------|:------------|
| 1 | **Scan & Connect** | Scans for BLE devices advertising as `SmartLED-*`, displays discovered devices, and connects on tap |
| 2 | **WiFi Configuration** | Text fields for SSID and password, writes credentials to BLE characteristics |
| 3 | **MQTT Configuration** | Text fields for broker address and port, writes config to BLE characteristics |
| 4 | **Verify Connection** | Sends `CONNECT` command, waits for status notification, displays WiFi/MQTT connection results |

#### Control Screen -- Dashboard

The main interface after setup, featuring:
- **LED Control Card** -- Mode toggle (Auto/Manual), individual LED on/off buttons with animated glow effect, vertical brightness sliders, and quick preset buttons (Off, 25%, 50%, 100%)
- **Sensor Grid** -- Four cards displaying temperature (color-coded), humidity, light level (lux), and atmospheric pressure
- **Motion Indicator** -- Animated indicator when the PIR sensor detects motion
- **Connection Status** -- Visual feedback for MQTT connection state
- **Menu Options** -- Reconnect, setup new device, or reset configuration

### Theme & Design

| Property | Value |
|:---------|:------|
| Design System | Material 3 |
| Color Seed | Indigo (`#6366F1`) |
| Background | Dark (`#0F0F23`) |
| Card Background | Dark Surface (`#1A1A2E`) |
| Border Radius | 16px |
| Fonts | Google Fonts |

---

## Automatic Mode Logic

When the system is set to **Auto** mode, the ESP32 firmware handles LED control autonomously:

```
                    +------------------+
                    | Sensor Reading   |
                    | (continuous)     |
                    +--------+---------+
                             |
                    +--------v---------+
                    | Motion Detected? |
                    +--------+---------+
                        |          |
                       YES         NO
                        |          |
               +--------v-------+  |
               | Light < 30 lux?|  |
               +--------+-------+  |
                   |         |     |
                  YES        NO    |
                   |         |     |
          +--------v---+     |     |
          | LEDs ON    |     |     |
          | (Full PWM) |     |     |
          +--------+---+     |     |
                   |         |     |
                   v         v     v
              +---------+  +----------+
              |Wait 10s |  | LEDs OFF |
              |no motion|  +----------+
              +----+----+
                   |
                   v
              +----------+
              | LEDs OFF |
              +----------+
```

**Thresholds (configurable in firmware):**

| Parameter | Default | Description |
|:----------|:--------|:------------|
| `LUX_ON_THRESHOLD` | `30.0` lux | Maximum ambient light for auto-activation |
| `OFF_DELAY_MS` | `10000` ms | Delay before turning off after last motion |

---

## Data Persistence

### ESP32 -- Non-Volatile Storage (NVS)

Settings are stored under the `"smarthome"` namespace and survive power cycles and firmware updates:

| Key | Content | Example |
|:----|:--------|:--------|
| `wifi_ssid` | WiFi network name | `"HomeNetwork"` |
| `wifi_pass` | WiFi password | `"********"` |
| `mqtt_broker` | MQTT broker address | `"192.168.1.100"` |
| `mqtt_port` | MQTT broker port | `"1883"` |
| `device_id` | Unique device identifier | `"a1b2c3d4e5f6a7b8"` |

### Flutter App -- SharedPreferences

| Key | Content | Purpose |
|:----|:--------|:--------|
| `device_id` | Last provisioned device ID | MQTT topic construction |
| `wifi_ssid` | Last configured SSID | Display in UI |
| `mqtt_broker` | Last configured broker | Auto-reconnect |
| `mqtt_port` | Last configured port | Auto-reconnect |

---

## Android Permissions

The app requires the following permissions (declared in `AndroidManifest.xml`):

| Permission | Purpose | Required For |
|:-----------|:--------|:-------------|
| `BLUETOOTH` | Basic Bluetooth access | BLE provisioning |
| `BLUETOOTH_ADMIN` | Bluetooth management | BLE scanning |
| `BLUETOOTH_SCAN` | BLE device discovery | Android 12+ |
| `BLUETOOTH_CONNECT` | BLE device connection | Android 12+ |
| `ACCESS_FINE_LOCATION` | Location for BLE scanning | Android requirement for BLE |
| `INTERNET` | Network communication | MQTT connection |
| `ACCESS_NETWORK_STATE` | Network status checks | Connection monitoring |

**Minimum Android Version:** API 21 (Android 5.0 Lollipop)

---

## Project Structure

```
Smart-Home-LED-Control-ESP32-And-Flutter/
|
|-- ESP32/                              # Firmware
|   |-- platformio.ini                  # Build configuration & dependencies
|   |-- src/
|   |   |-- main.cpp                    # Complete firmware source (~680 lines)
|   |-- include/                        # Header files
|   |-- lib/                            # Local libraries
|   |-- test/                           # Unit tests
|
|-- FlutterApp/                         # Mobile application
|   |-- pubspec.yaml                    # Dart/Flutter dependencies
|   |-- lib/
|   |   |-- main.dart                   # App entry point & theme
|   |   |-- screens/
|   |   |   |-- home_screen.dart        # Router screen
|   |   |   |-- setup_screen.dart       # BLE provisioning wizard
|   |   |   |-- control_screen.dart     # Dashboard & controls
|   |   |-- services/
|   |   |   |-- ble_service.dart        # BLE communication layer
|   |   |   |-- mqtt_service.dart       # MQTT client & state
|   |   |   |-- device_state.dart       # Persistent storage
|   |   |-- widgets/
|   |   |   |-- led_control_card.dart   # LED control UI component
|   |   |   |-- sensor_card.dart        # Sensor display component
|   |   |-- models/                     # Data models (reserved)
|   |-- android/                        # Android native config
|   |-- ios/                            # iOS native config
|
|-- README.md                           # This file
```

---

## Tech Stack

<table>
<tr>
<td align="center" width="150">

**ESP32**<br/>
Arduino Framework<br/>
PlatformIO

</td>
<td align="center" width="150">

**Flutter**<br/>
Dart 3.0+<br/>
Material 3

</td>
<td align="center" width="150">

**BLE**<br/>
GATT Server<br/>
flutter_blue_plus

</td>
<td align="center" width="150">

**MQTT**<br/>
PubSubClient<br/>
mqtt_client

</td>
<td align="center" width="150">

**Sensors**<br/>
BH1750 + BME280<br/>
PIR HC-SR501

</td>
</tr>
</table>

### Firmware Dependencies

| Library | Purpose |
|:--------|:--------|
| [BH1750](https://github.com/claws/BH1750) | Ambient light sensor driver |
| [Adafruit BME280](https://github.com/adafruit/Adafruit_BME280_Library) | Temperature, humidity, pressure sensor |
| [Adafruit Unified Sensor](https://github.com/adafruit/Adafruit_Sensor) | Sensor abstraction layer |
| [PubSubClient](https://github.com/knolleary/pubsubclient) | MQTT client for Arduino |
| [ArduinoJson](https://github.com/bblanchon/ArduinoJson) | JSON serialization/deserialization |

### Flutter Dependencies

| Package | Version | Purpose |
|:--------|:--------|:--------|
| [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) | ^1.31.0 | BLE device communication |
| [permission_handler](https://pub.dev/packages/permission_handler) | ^11.3.0 | Runtime permission management |
| [mqtt_client](https://pub.dev/packages/mqtt_client) | ^10.2.0 | MQTT protocol client |
| [provider](https://pub.dev/packages/provider) | ^6.1.1 | State management |
| [shared_preferences](https://pub.dev/packages/shared_preferences) | ^2.2.2 | Local key-value storage |
| [google_fonts](https://pub.dev/packages/google_fonts) | ^6.1.0 | Custom typography |
| [flutter_svg](https://pub.dev/packages/flutter_svg) | ^2.0.9 | SVG rendering |

---

## Troubleshooting

<details>
<summary><strong>BLE device not appearing in scan</strong></summary>

- Ensure Bluetooth and Location are enabled on your phone
- On Android 12+, grant "Nearby Devices" permission
- Power-cycle the ESP32 to restart BLE advertising
- The device only advertises when not connected to another client

</details>

<details>
<summary><strong>WiFi connection fails during provisioning</strong></summary>

- Verify SSID and password are correct (case-sensitive)
- ESP32 supports 2.4 GHz WiFi only (not 5 GHz)
- Ensure the router is within range
- Check the serial monitor (`pio device monitor`) for error messages

</details>

<details>
<summary><strong>MQTT connection fails</strong></summary>

- Verify the MQTT broker is running and accessible on the network
- Check that the broker IP/hostname is correct
- Default port is `1883` -- ensure it matches your broker config
- Verify no firewall is blocking the MQTT port
- Check broker logs for connection attempts

</details>

<details>
<summary><strong>Sensor readings show 0 or N/A</strong></summary>

- Verify I2C wiring (SDA to GPIO21, SCL to GPIO22)
- Check sensor power supply (3.3V, not 5V for BME280)
- The BH1750 auto-detects addresses `0x23` and `0x5C` -- ensure no address conflict
- Run an I2C scanner sketch to verify sensors are detected

</details>

<details>
<summary><strong>LEDs not responding to commands</strong></summary>

- Verify LED wiring to GPIO25 (LED1) and GPIO26 (LED2)
- Check that LEDs have appropriate current-limiting resistors
- In Auto mode, manual commands are ignored -- switch to Manual mode
- Verify MQTT connection is active (check the connection indicator in the app)

</details>

---

## License

This project is open source. Feel free to use, modify, and distribute.

---

<p align="center">
  Built with ESP32 + Flutter + MQTT
</p>
