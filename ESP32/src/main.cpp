/*
 * Smart Home LED Control
 * ESP32 firmware s BLE provisioningom, WiFi i MQTT kontrolom
 * Zasebna kontrola LED1 i LED2
 */

#include <Arduino.h>
#include <Wire.h>
#include <BH1750.h>
#include <Adafruit_BME280.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Preferences.h>
#include <ArduinoJson.h>

// ==================== PINOVI ====================
static const int PIN_PIR = 27;
static const int PIN_LED1 = 25;
static const int PIN_LED2 = 26;

// PWM konfiguracija
static const int PWM_FREQ = 5000;
static const int PWM_RESOLUTION = 8; // 0-255
static const int PWM_CHANNEL_1 = 0;
static const int PWM_CHANNEL_2 = 1;

// ==================== PRAVILA ====================
static const float LUX_ON_THRESHOLD = 30.0f;
static const uint32_t OFF_DELAY_MS = 10UL * 1000UL; // 10 sekundi

// ==================== BLE UUIDs ====================
#define SERVICE_UUID           "12345678-1234-1234-1234-123456789abc"
#define CHAR_WIFI_SSID_UUID    "12345678-1234-1234-1234-123456789ab1"
#define CHAR_WIFI_PASS_UUID    "12345678-1234-1234-1234-123456789ab2"
#define CHAR_MQTT_BROKER_UUID  "12345678-1234-1234-1234-123456789ab3"
#define CHAR_MQTT_PORT_UUID    "12345678-1234-1234-1234-123456789ab4"
#define CHAR_DEVICE_ID_UUID    "12345678-1234-1234-1234-123456789ab5"
#define CHAR_STATUS_UUID       "12345678-1234-1234-1234-123456789ab6"
#define CHAR_COMMAND_UUID      "12345678-1234-1234-1234-123456789ab7"

// ==================== MQTT TOPICI ====================
#define MQTT_TOPIC_LED_SET     "smarthome/%s/led/set"
#define MQTT_TOPIC_LED_STATUS  "smarthome/%s/led/status"
#define MQTT_TOPIC_SENSORS     "smarthome/%s/sensors"
#define MQTT_TOPIC_CONFIG      "smarthome/%s/config"

// ==================== GLOBALNE VARIJABLE ====================
// Senzori
BH1750 bh1750;
Adafruit_BME280 bme280;
bool bh1750Ok = false;
bool bme280Ok = false;

// WiFi & MQTT
WiFiClient wifiClient;
PubSubClient mqttClient(wifiClient);
Preferences preferences;

// Konfiguracija (spremljena u NVS)
String wifiSSID = "";
String wifiPassword = "";
String mqttBroker = "";
int mqttPort = 1883;
String deviceId = "";

// Stanje
bool wifiConnected = false;
bool mqttConnected = false;
uint32_t lastMotionMs = 0;
uint32_t lastMqttReconnect = 0;
uint32_t lastSensorPublish = 0;

// LED stanje - zasebno za svaku LED
bool led1State = false;
bool led2State = false;
uint8_t led1Brightness = 255;
uint8_t led2Brightness = 255;
bool manualMode = false; // true = app kontrolira, false = automatski (PIR+lux)

// BLE
BLEServer* pServer = nullptr;
BLECharacteristic* pStatusChar = nullptr;
bool bleClientConnected = false;
bool shouldReconnectWifi = false;

// MQTT topic bufferi
char topicLedSet[64];
char topicLedStatus[64];
char topicSensors[64];
char topicConfig[64];

// ==================== FUNKCIJE ====================

void setLed1(bool on, uint8_t brightness = 255) {
  led1State = on;
  led1Brightness = brightness;
  uint8_t pwmValue = on ? brightness : 0;
  ledcWrite(PWM_CHANNEL_1, pwmValue);
}

void setLed2(bool on, uint8_t brightness = 255) {
  led2State = on;
  led2Brightness = brightness;
  uint8_t pwmValue = on ? brightness : 0;
  ledcWrite(PWM_CHANNEL_2, pwmValue);
}

void setAllLeds(bool on, uint8_t brightness = 255) {
  setLed1(on, brightness);
  setLed2(on, brightness);
}

void saveConfig() {
  preferences.begin("smarthome", false);
  preferences.putString("wifi_ssid", wifiSSID);
  preferences.putString("wifi_pass", wifiPassword);
  preferences.putString("mqtt_broker", mqttBroker);
  preferences.putInt("mqtt_port", mqttPort);
  preferences.putString("device_id", deviceId);
  preferences.end();
  Serial.println("Konfiguracija spremljena.");
}

void loadConfig() {
  preferences.begin("smarthome", true);
  wifiSSID = preferences.getString("wifi_ssid", "");
  wifiPassword = preferences.getString("wifi_pass", "");
  mqttBroker = preferences.getString("mqtt_broker", "");
  mqttPort = preferences.getInt("mqtt_port", 1883);
  deviceId = preferences.getString("device_id", "");
  preferences.end();

  // Ako nema device ID, generiraj ga
  if (deviceId.isEmpty()) {
    uint64_t chipId = ESP.getEfuseMac();
    deviceId = String((uint32_t)(chipId >> 32), HEX) + String((uint32_t)chipId, HEX);
    preferences.begin("smarthome", false);
    preferences.putString("device_id", deviceId);
    preferences.end();
  }

  Serial.println("Konfiguracija učitana:");
  Serial.println("  SSID: " + wifiSSID);
  Serial.println("  MQTT Broker: " + mqttBroker);
  Serial.println("  MQTT Port: " + String(mqttPort));
  Serial.println("  Device ID: " + deviceId);
}

void setupMqttTopics() {
  snprintf(topicLedSet, sizeof(topicLedSet), MQTT_TOPIC_LED_SET, deviceId.c_str());
  snprintf(topicLedStatus, sizeof(topicLedStatus), MQTT_TOPIC_LED_STATUS, deviceId.c_str());
  snprintf(topicSensors, sizeof(topicSensors), MQTT_TOPIC_SENSORS, deviceId.c_str());
  snprintf(topicConfig, sizeof(topicConfig), MQTT_TOPIC_CONFIG, deviceId.c_str());
}

void publishLedStatus() {
  if (!mqttConnected) return;

  StaticJsonDocument<300> doc;

  // LED1
  JsonObject led1 = doc.createNestedObject("led1");
  led1["state"] = led1State ? "on" : "off";
  led1["brightness"] = led1Brightness;

  // LED2
  JsonObject led2 = doc.createNestedObject("led2");
  led2["state"] = led2State ? "on" : "off";
  led2["brightness"] = led2Brightness;

  doc["mode"] = manualMode ? "manual" : "auto";

  char buffer[300];
  serializeJson(doc, buffer);
  mqttClient.publish(topicLedStatus, buffer, true);
}

void publishSensorData() {
  if (!mqttConnected) return;

  float lux = bh1750Ok ? bh1750.readLightLevel() : -1;
  float temp = bme280Ok ? bme280.readTemperature() : -1;
  float humidity = bme280Ok ? bme280.readHumidity() : -1;
  float pressure = bme280Ok ? (bme280.readPressure() / 100.0f) : -1;
  int pir = digitalRead(PIN_PIR);

  StaticJsonDocument<400> doc;
  doc["lux"] = lux;
  doc["temperature"] = temp;
  doc["humidity"] = humidity;
  doc["pressure"] = pressure;
  doc["motion"] = pir == HIGH;

  // LED1 status
  JsonObject led1 = doc.createNestedObject("led1");
  led1["state"] = led1State;
  led1["brightness"] = led1Brightness;

  // LED2 status
  JsonObject led2 = doc.createNestedObject("led2");
  led2["state"] = led2State;
  led2["brightness"] = led2Brightness;

  doc["mode"] = manualMode ? "manual" : "auto";

  char buffer[400];
  serializeJson(doc, buffer);
  mqttClient.publish(topicSensors, buffer);
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String message;
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }

  Serial.print("MQTT primljeno [");
  Serial.print(topic);
  Serial.print("]: ");
  Serial.println(message);

  if (String(topic) == topicLedSet) {
    StaticJsonDocument<300> doc;
    DeserializationError error = deserializeJson(doc, message);

    if (error) {
      Serial.println("JSON parse error");
      return;
    }

    // Mode
    if (doc.containsKey("mode")) {
      String mode = doc["mode"].as<String>();
      manualMode = (mode == "manual");
    }

    // LED1 kontrola
    if (doc.containsKey("led1")) {
      JsonObject led1Obj = doc["led1"];
      uint8_t brightness = led1Obj.containsKey("brightness") ? led1Obj["brightness"].as<uint8_t>() : led1Brightness;

      if (led1Obj.containsKey("state") && manualMode) {
        String state = led1Obj["state"].as<String>();
        setLed1(state == "on", brightness);
      } else if (led1Obj.containsKey("brightness") && manualMode) {
        setLed1(led1State, brightness);
      }
    }

    // LED2 kontrola
    if (doc.containsKey("led2")) {
      JsonObject led2Obj = doc["led2"];
      uint8_t brightness = led2Obj.containsKey("brightness") ? led2Obj["brightness"].as<uint8_t>() : led2Brightness;

      if (led2Obj.containsKey("state") && manualMode) {
        String state = led2Obj["state"].as<String>();
        setLed2(state == "on", brightness);
      } else if (led2Obj.containsKey("brightness") && manualMode) {
        setLed2(led2State, brightness);
      }
    }

    // Kontrola obje LED zajedno (backward compatibility)
    if (doc.containsKey("state") && manualMode && !doc.containsKey("led1") && !doc.containsKey("led2")) {
      String state = doc["state"].as<String>();
      uint8_t brightness = doc.containsKey("brightness") ? doc["brightness"].as<uint8_t>() : 255;
      setAllLeds(state == "on", brightness);
    }

    publishLedStatus();
  }
}

void connectWifi() {
  if (wifiSSID.isEmpty()) {
    Serial.println("WiFi SSID nije konfiguriran");
    return;
  }

  Serial.print("Spajanje na WiFi: ");
  Serial.println(wifiSSID);

  WiFi.mode(WIFI_STA);
  WiFi.begin(wifiSSID.c_str(), wifiPassword.c_str());

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    wifiConnected = true;
    Serial.println();
    Serial.print("WiFi spojen! IP: ");
    Serial.println(WiFi.localIP());
  } else {
    wifiConnected = false;
    Serial.println();
    Serial.println("WiFi spajanje neuspješno!");
  }
}

void connectMqtt() {
  if (!wifiConnected || mqttBroker.isEmpty()) return;

  if (!mqttClient.connected()) {
    Serial.print("Spajanje na MQTT broker: ");
    Serial.println(mqttBroker);

    String clientId = "esp32-" + deviceId;

    if (mqttClient.connect(clientId.c_str())) {
      mqttConnected = true;
      Serial.println("MQTT spojen!");

      // Subscribe na LED set topic
      mqttClient.subscribe(topicLedSet);
      Serial.print("Subscribed: ");
      Serial.println(topicLedSet);

      // Objavi početni status
      publishLedStatus();
      publishSensorData();
    } else {
      mqttConnected = false;
      Serial.print("MQTT spajanje neuspješno, rc=");
      Serial.println(mqttClient.state());
    }
  }
}

String getStatusJson() {
  StaticJsonDocument<300> doc;
  doc["wifi_connected"] = wifiConnected;
  doc["wifi_ssid"] = wifiSSID;
  doc["mqtt_connected"] = mqttConnected;
  doc["mqtt_broker"] = mqttBroker;
  doc["device_id"] = deviceId;
  doc["ip"] = wifiConnected ? WiFi.localIP().toString() : "";

  String output;
  serializeJson(doc, output);
  return output;
}

// ==================== BLE CALLBACKS ====================
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    bleClientConnected = true;
    Serial.println("BLE klijent spojen");
  }

  void onDisconnect(BLEServer* pServer) {
    bleClientConnected = false;
    Serial.println("BLE klijent odspojen");
    pServer->startAdvertising();
  }
};

class WiFiSSIDCallback : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    String value = pCharacteristic->getValue().c_str();
    if (value.length() > 0) {
      wifiSSID = value;
      Serial.println("Primljen WiFi SSID: " + wifiSSID);
    }
  }
};

class WiFiPassCallback : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    String value = pCharacteristic->getValue().c_str();
    if (value.length() > 0) {
      wifiPassword = value;
      Serial.println("Primljen WiFi password");
    }
  }
};

class MQTTBrokerCallback : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    String value = pCharacteristic->getValue().c_str();
    if (value.length() > 0) {
      mqttBroker = value;
      Serial.println("Primljen MQTT broker: " + mqttBroker);
    }
  }
};

class MQTTPortCallback : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    String value = pCharacteristic->getValue().c_str();
    if (value.length() > 0) {
      mqttPort = value.toInt();
      Serial.println("Primljen MQTT port: " + String(mqttPort));
    }
  }
};

class DeviceIDCallback : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    String value = pCharacteristic->getValue().c_str();
    if (value.length() > 0) {
      deviceId = value;
      Serial.println("Primljen Device ID: " + deviceId);
    }
  }
};

class CommandCallback : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    String value = pCharacteristic->getValue().c_str();
    Serial.println("BLE naredba: " + value);

    if (value == "SAVE") {
      saveConfig();
      setupMqttTopics();
      pStatusChar->setValue("CONFIG_SAVED");
      pStatusChar->notify();
    }
    else if (value == "CONNECT") {
      saveConfig();
      setupMqttTopics();
      shouldReconnectWifi = true;
      pStatusChar->setValue("CONNECTING");
      pStatusChar->notify();
    }
    else if (value == "STATUS") {
      String status = getStatusJson();
      pStatusChar->setValue(status.c_str());
      pStatusChar->notify();
    }
    else if (value == "RESET") {
      preferences.begin("smarthome", false);
      preferences.clear();
      preferences.end();
      pStatusChar->setValue("CONFIG_RESET");
      pStatusChar->notify();
      delay(1000);
      ESP.restart();
    }
  }
};

void setupBLE() {
  String bleName = "SmartLED-" + deviceId.substring(0, 6);
  BLEDevice::init(bleName.c_str());

  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  // 32 handleova za 7 karakteristika + deskriptore
  BLEService* pService = pServer->createService(BLEUUID(SERVICE_UUID), 32);

  // WiFi SSID
  BLECharacteristic* pSSIDChar = pService->createCharacteristic(
    CHAR_WIFI_SSID_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE
  );
  pSSIDChar->setCallbacks(new WiFiSSIDCallback());
  pSSIDChar->setValue(wifiSSID.c_str());

  // WiFi Password
  BLECharacteristic* pPassChar = pService->createCharacteristic(
    CHAR_WIFI_PASS_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  pPassChar->setCallbacks(new WiFiPassCallback());

  // MQTT Broker
  BLECharacteristic* pBrokerChar = pService->createCharacteristic(
    CHAR_MQTT_BROKER_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE
  );
  pBrokerChar->setCallbacks(new MQTTBrokerCallback());
  pBrokerChar->setValue(mqttBroker.c_str());

  // MQTT Port
  BLECharacteristic* pPortChar = pService->createCharacteristic(
    CHAR_MQTT_PORT_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE
  );
  pPortChar->setCallbacks(new MQTTPortCallback());
  pPortChar->setValue(String(mqttPort).c_str());

  // Device ID
  BLECharacteristic* pDeviceIdChar = pService->createCharacteristic(
    CHAR_DEVICE_ID_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE
  );
  pDeviceIdChar->setCallbacks(new DeviceIDCallback());
  pDeviceIdChar->setValue(deviceId.c_str());

  // Status (notify)
  pStatusChar = pService->createCharacteristic(
    CHAR_STATUS_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pStatusChar->addDescriptor(new BLE2902());
  pStatusChar->setValue("READY");

  // Command
  BLECharacteristic* pCmdChar = pService->createCharacteristic(
    CHAR_COMMAND_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  pCmdChar->setCallbacks(new CommandCallback());

  pService->start();

  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  BLEDevice::startAdvertising();

  Serial.println("BLE pokrenut: " + bleName);
}

// ==================== SETUP ====================
void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("\n=== Smart Home LED Control ===");

  // Pinovi
  pinMode(PIN_PIR, INPUT);

  // PWM setup
  ledcSetup(PWM_CHANNEL_1, PWM_FREQ, PWM_RESOLUTION);
  ledcSetup(PWM_CHANNEL_2, PWM_FREQ, PWM_RESOLUTION);
  ledcAttachPin(PIN_LED1, PWM_CHANNEL_1);
  ledcAttachPin(PIN_LED2, PWM_CHANNEL_2);
  setAllLeds(false);

  // I2C
  Wire.begin(21, 22);

  // BH1750
  if (bh1750.begin(BH1750::CONTINUOUS_HIGH_RES_MODE)) {
    bh1750Ok = true;
    Serial.println("BH1750 OK");
  } else {
    Serial.println("BH1750 FAIL");
  }

  // BME280
  if (bme280.begin(0x76) || bme280.begin(0x77)) {
    bme280Ok = true;
    Serial.println("BME280 OK");
  } else {
    Serial.println("BME280 FAIL");
  }

  // Učitaj konfiguraciju
  loadConfig();
  setupMqttTopics();

  // Pokreni BLE
  setupBLE();

  // Spoji WiFi ako je konfiguriran
  if (!wifiSSID.isEmpty()) {
    connectWifi();

    if (wifiConnected && !mqttBroker.isEmpty()) {
      mqttClient.setServer(mqttBroker.c_str(), mqttPort);
      mqttClient.setCallback(mqttCallback);
      connectMqtt();
    }
  }

  Serial.println("Sustav spreman!");
}

// ==================== LOOP ====================
void loop() {
  // WiFi reconnect ako je zatraženo preko BLE
  if (shouldReconnectWifi) {
    shouldReconnectWifi = false;
    WiFi.disconnect();
    delay(500);
    connectWifi();

    if (wifiConnected && !mqttBroker.isEmpty()) {
      mqttClient.setServer(mqttBroker.c_str(), mqttPort);
      mqttClient.setCallback(mqttCallback);
      connectMqtt();
    }

    // Ažuriraj BLE status
    if (pStatusChar) {
      String status = getStatusJson();
      pStatusChar->setValue(status.c_str());
      pStatusChar->notify();
    }
  }

  // MQTT loop
  if (wifiConnected && !mqttBroker.isEmpty()) {
    if (!mqttClient.connected()) {
      mqttConnected = false;
      if (millis() - lastMqttReconnect > 5000) {
        lastMqttReconnect = millis();
        connectMqtt();
      }
    } else {
      mqttClient.loop();
    }
  }

  // PIR detekcija
  int pir = digitalRead(PIN_PIR);
  if (pir == HIGH) {
    lastMotionMs = millis();
  }

  // Automatska kontrola (ako nije u manual modu)
  // LED se pali SAMO kad ima pokreta I mrak je
  // Gasi se 10 sekundi nakon zadnjeg pokreta
  if (!manualMode) {
    float lux = bh1750Ok ? bh1750.readLightLevel() : 0;
    bool darkEnough = (lux >= 0.0f) ? (lux < LUX_ON_THRESHOLD) : true;
    bool motionRecently = (millis() - lastMotionMs) < OFF_DELAY_MS;

    // Pali samo ako je mrak I ima pokreta
    bool shouldBeOn = darkEnough && motionRecently;

    // Provjeri treba li promijeniti stanje
    bool currentState = led1State || led2State;
    if (shouldBeOn != currentState) {
      setAllLeds(shouldBeOn, 255);
      publishLedStatus();

      if (shouldBeOn) {
        Serial.println("AUTO: Pokret detektiran u mraku - LED ON");
      } else {
        Serial.println("AUTO: Nema pokreta 10s - LED OFF");
      }
    }
  }

  // Objavi senzorske podatke svakih 5 sekundi
  if (mqttConnected && (millis() - lastSensorPublish > 5000)) {
    lastSensorPublish = millis();
    publishSensorData();
  }

  // Debug ispis (svakih 5s)
  static uint32_t lastPrint = 0;
  if (millis() - lastPrint > 5000) {
    lastPrint = millis();

    Serial.print("WiFi:");
    Serial.print(wifiConnected ? "OK" : "NO");
    Serial.print(" MQTT:");
    Serial.print(mqttConnected ? "OK" : "NO");
    Serial.print(" BLE:");
    Serial.print(bleClientConnected ? "CONN" : "ADV");
    Serial.print(" Mode:");
    Serial.print(manualMode ? "MANUAL" : "AUTO");
    Serial.print(" LED1:");
    Serial.print(led1State ? "ON" : "OFF");
    Serial.print("(");
    Serial.print(led1Brightness);
    Serial.print(") LED2:");
    Serial.print(led2State ? "ON" : "OFF");
    Serial.print("(");
    Serial.print(led2Brightness);
    Serial.println(")");
  }

  delay(20);
}
