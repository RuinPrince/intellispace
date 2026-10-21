/*
 * ======================================================================================
 * IntelliSpace Smart Campus Automation System — ESP8266 NodeMCU Firmware (v2.2)
 * ======================================================================================
 * Hardware Components:
 *   - ESP8266 NodeMCU (Amica / CP2102 or CH340)
 *   - 2-Channel 5V Relay Module
 *   - Channel 1 Relay -> 5V DC Fan  (Maps to App Device ID: 4 "Exhaust Ventilation Fan")
 *   - Channel 2 Relay -> 5V LED     (Maps to App Device ID: 1 "Main Ceiling Lights")
 * 
 * Cloud Backend:
 *   - Supabase Cloud PostgreSQL REST API (HTTPS)
 * 
 * Functionality:
 *   - Polls device states every 1.5s via HTTPS GET
 *   - Direct relay actuation (Active-LOW support)
 *   - Embedded local web server on port 80 for emergency fallback control
 *   - No telemetry pushing (streamlined firmware)
 * ======================================================================================
 */

#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ESP8266WebServer.h>
#include <ArduinoJson.h>

// ======================================================================================
// 1. Wi-Fi Configuration
// ======================================================================================
const char* WIFI_SSID     = "Intellispace";
const char* WIFI_PASSWORD = "Intel@dyics2024";

// ======================================================================================
// 2. Supabase Cloud Configuration
// ======================================================================================
const char* SUPABASE_HOST = "xuwsvnhirrkxktcveovp.supabase.co";
const char* SUPABASE_KEY  = "sb_publishable_DKDalHd5MGcTaqJK5ptsFQ_8c6RWpUa";

// Endpoints
const String URL_GET_DEVICES = "https://xuwsvnhirrkxktcveovp.supabase.co/rest/v1/devices?select=id,device_name,device_type,power_state&order=id.asc";

// ======================================================================================
// 3. Hardware Pin Definitions (NodeMCU)
// ======================================================================================
#define RELAY_FAN_PIN   D2  // GPIO 4 -> Relay for Fan (Pin D2)
#define RELAY_LIGHT_PIN D1  // GPIO 5 -> Relay Channel 1 (Auxiliary / Light)
#define STATUS_LED_PIN  D4  // GPIO 2 -> Built-in LED on NodeMCU

// Set to true for Active-LOW relays (Songle 5V blue relay modules trigger on LOW)
const bool RELAY_ACTIVE_LOW = true;

// State tracking
bool isFanOn   = false;
bool isLightOn = false;
bool isInitialSyncDone = false;
unsigned long lastDevicePollTime = 0;

const unsigned long DEVICE_POLL_INTERVAL = 1500;  // Poll cloud device states every 1.5 seconds

// Embedded local web server on port 80 (allows direct browser control too!)
ESP8266WebServer localServer(80);

// ======================================================================================
// RELAY CONTROLLER
// ======================================================================================
void applyRelayState(int pin, bool turnOn) {
  pinMode(pin, OUTPUT);
  if (RELAY_ACTIVE_LOW) {
    digitalWrite(pin, turnOn ? LOW : HIGH);
  } else {
    digitalWrite(pin, turnOn ? HIGH : LOW);
  }
}

// ======================================================================================
// LOCAL WEB SERVER HANDLERS (Direct IP Control Fallback)
// ======================================================================================
void handleRoot() {
  String html = "<!DOCTYPE html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'>";
  html += "<title>IntelliSpace Hardware Node</title>";
  html += "<style>body{font-family:sans-serif;text-align:center;background:#0f172a;color:#fff;padding:20px;}";
  html += ".btn{display:inline-block;padding:16px 32px;font-size:18px;margin:12px;border-radius:12px;text-decoration:none;font-weight:bold;}";
  html += ".on{background:#10b981;color:#fff;} .off{background:#ef4444;color:#fff;}";
  html += ".card{background:#1e293b;padding:20px;border-radius:16px;max-width:400px;margin:20px auto;}</style></head><body>";
  html += "<h2>⚡ IntelliSpace Hardware Controller</h2>";
  html += "<div class='card'><h3>🌀 Exhaust Fan: " + String(isFanOn ? "<span style='color:#10b981'>ON</span>" : "<span style='color:#ef4444'>OFF</span>") + "</h3>";
  html += "<a class='btn on' href='/fan/on'>TURN FAN ON</a><a class='btn off' href='/fan/off'>TURN FAN OFF</a></div>";
  html += "<div class='card'><h3>💡 Ceiling Lights: " + String(isLightOn ? "<span style='color:#10b981'>ON</span>" : "<span style='color:#ef4444'>OFF</span>") + "</h3>";
  html += "<a class='btn on' href='/light/on'>TURN LIGHT ON</a><a class='btn off' href='/light/off'>TURN LIGHT OFF</a></div>";
  html += "<p style='color:#94a3b8'>Supabase Cloud Sync: ACTIVE</p></body></html>";
  localServer.send(200, "text/html", html);
}

void handleFanOn() {
  isFanOn = true;
  applyRelayState(RELAY_FAN_PIN, true);
  Serial.println(F("[DIRECT] Fan turned ON via local server"));
  localServer.sendHeader("Location", "/");
  localServer.send(303);
}

void handleFanOff() {
  isFanOn = false;
  applyRelayState(RELAY_FAN_PIN, false);
  Serial.println(F("[DIRECT] Fan turned OFF via local server"));
  localServer.sendHeader("Location", "/");
  localServer.send(303);
}

void handleLightOn() {
  isLightOn = true;
  applyRelayState(RELAY_LIGHT_PIN, true);
  Serial.println(F("[DIRECT] Light turned ON via local server"));
  localServer.sendHeader("Location", "/");
  localServer.send(303);
}

void handleLightOff() {
  isLightOn = false;
  applyRelayState(RELAY_LIGHT_PIN, false);
  Serial.println(F("[DIRECT] Light turned OFF via local server"));
  localServer.sendHeader("Location", "/");
  localServer.send(303);
}

// ======================================================================================
// SETUP
// ======================================================================================
void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println();
  Serial.println(F("========================================================="));
  Serial.println(F("   INTELLISPACE SMART CAMPUS — ESP8266 FIRMWARE v2.2    "));
  Serial.println(F("========================================================="));

  // Initialize status LED
  pinMode(STATUS_LED_PIN, OUTPUT);
  digitalWrite(STATUS_LED_PIN, HIGH); // LED off

  // Initialize pins strictly to OFF
  pinMode(RELAY_FAN_PIN, OUTPUT);
  pinMode(RELAY_LIGHT_PIN, OUTPUT);
  applyRelayState(RELAY_FAN_PIN, false);
  applyRelayState(RELAY_LIGHT_PIN, false);

  // -------------------------------------------------------------
  // BOOT SELF-TEST: Confirms Fan relay function physically
  // -------------------------------------------------------------
  Serial.println(F("[HARDWARE TEST] Testing Fan Relay (Pin D2)..."));
  applyRelayState(RELAY_FAN_PIN, true);   // Click Fan ON
  delay(1200);                            // Fan spins for 1.2s
  applyRelayState(RELAY_FAN_PIN, false);  // Click Fan OFF
  Serial.println(F("[HARDWARE TEST] Hardware test complete! Fan on Pin D2 ready."));
  Serial.println(F("---------------------------------------------------------"));

  // Connect to Wi-Fi
  connectWiFi();

  // Setup local web server routes
  localServer.on("/", handleRoot);
  localServer.on("/fan/on", handleFanOn);
  localServer.on("/fan/off", handleFanOff);
  localServer.on("/light/on", handleLightOn);
  localServer.on("/light/off", handleLightOff);
  localServer.begin();
  Serial.println(F("[SERVER] Local Web Controller started on port 80"));
}

// ======================================================================================
// MAIN LOOP
// ======================================================================================
void loop() {
  // Ensure Wi-Fi connection is maintained
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  // Handle local HTTP requests (browser control)
  localServer.handleClient();

  unsigned long currentMillis = millis();

  // Check device states (Fan / Light) from Supabase Cloud
  if (currentMillis - lastDevicePollTime >= DEVICE_POLL_INTERVAL) {
    lastDevicePollTime = currentMillis;
    pollDeviceStates();
  }
}

// ======================================================================================
// WI-FI CONNECTION HELPER
// ======================================================================================
void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;

  Serial.print(F("[Wi-Fi] Connecting to: "));
  Serial.println(WIFI_SSID);

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 25) {
    delay(500);
    Serial.print(F("."));
    digitalWrite(STATUS_LED_PIN, !digitalRead(STATUS_LED_PIN)); // Blink while connecting
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    digitalWrite(STATUS_LED_PIN, LOW); // Solid ON when connected
    Serial.println();
    Serial.println(F("[Wi-Fi] Connected successfully!"));
    Serial.print(F("[Wi-Fi] NodeMCU IP Address: http://"));
    Serial.println(WiFi.localIP());
    Serial.print(F("[Wi-Fi] Signal Strength (RSSI): "));
    Serial.print(WiFi.RSSI());
    Serial.println(F(" dBm"));
  } else {
    Serial.println();
    Serial.println(F("[Wi-Fi] Connection failed! Check SSID & Password in lines 26-27."));
  }
}

// ======================================================================================
// CLOUD SYNC: POLL DEVICE STATES (FAN & LIGHT)
// ======================================================================================
void pollDeviceStates() {
  if (WiFi.status() != WL_CONNECTED) return;

  WiFiClientSecure client;
  client.setInsecure(); // Accept Supabase HTTPS SSL certificate
  client.setTimeout(4000);

  HTTPClient https;
  if (!https.begin(client, URL_GET_DEVICES)) {
    Serial.println(F("[HTTP] Failed to initialize connection to Supabase"));
    return;
  }

  https.addHeader("apikey", SUPABASE_KEY);
  https.addHeader("Authorization", String("Bearer ") + SUPABASE_KEY);
  https.addHeader("Accept", "application/json");

  int httpCode = https.GET();

  if (httpCode == HTTP_CODE_OK) {
    String payload = https.getString();

    // Parse JSON array of devices (ArduinoJson v6 & v7 compatible)
#if ARDUINOJSON_VERSION_MAJOR >= 7
    JsonDocument doc;
#else
    DynamicJsonDocument doc(1024);
#endif
    DeserializationError error = deserializeJson(doc, payload);

    if (!error) {
      JsonArray array = doc.as<JsonArray>();

      for (JsonObject device : array) {
        int id = device["id"];
        const char* type = device["device_type"] | "";
        const char* state = device["power_state"] | "OFF";
        bool shouldTurnOn = (strcmp(state, "ON") == 0);

        // Fan Control on Pin D2 (Matches Device 4 or type 'fan')
        if (id == 4 || strcmp(type, "fan") == 0) {
          if (!isInitialSyncDone || isFanOn != shouldTurnOn) {
            isFanOn = shouldTurnOn;
            applyRelayState(RELAY_FAN_PIN, isFanOn);
            Serial.printf("[CLOUD SYNC] Fan on Pin D2: %s\n", isFanOn ? "ON (SPINNING)" : "OFF (STOPPED)");
          }
        }

        // Light Control on Pin D1 (Matches Device 1 or type 'light')
        if (id == 1 || strcmp(type, "light") == 0) {
          if (!isInitialSyncDone || isLightOn != shouldTurnOn) {
            isLightOn = shouldTurnOn;
            applyRelayState(RELAY_LIGHT_PIN, isLightOn);
            Serial.printf("[CLOUD SYNC] Light on Pin D1: %s\n", isLightOn ? "ON" : "OFF");
          }
        }
      }
      isInitialSyncDone = true;
    } else {
      Serial.print(F("[JSON] Parse error: "));
      Serial.println(error.f_str());
    }
  } else {
    Serial.printf("[HTTP] GET devices failed, code: %d\n", httpCode);
  }

  https.end();
}
