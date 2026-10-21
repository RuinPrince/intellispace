/*
 * ======================================================================================
 * Relay Hardware Testing Firmware for NodeMCU ESP8266
 * ======================================================================================
 * Objective: 
 *   Keep Relay (Connected to Pin D1) permanently ON (COM connected to NO).
 *   No Wi-Fi, No Cloud, No App, No Supabase.
 *   Pure hardware sanity check to test if the relay clicks and stays energized.
 * 
 * Pinout Connections:
 *   - Relay VCC  --> NodeMCU VIN (5V from USB)
 *   - Relay GND  --> NodeMCU GND
 *   - Relay IN1  --> NodeMCU D1  (GPIO 5)
 * ======================================================================================
 */

#define RELAY_PIN       D1    // NodeMCU GPIO 5 (Connected to Relay IN1)
#define RELAY_PIN_2     D2    // NodeMCU GPIO 4 (Connected to Relay IN2)
#define ONBOARD_LED     LED_BUILTIN // GPIO 2 (NodeMCU built-in blue LED)

/* 
 * CRITICAL NOTE ON RELAY TRIGGER TYPES:
 * Most standard 5V blue Songle relay modules are ACTIVE-LOW:
 *   - Writing LOW  energizes the relay coil (Clicks -> NO closes/turns ON).
 *   - Writing HIGH de-energizes the relay coil (NO opens/turns OFF).
 *
 * If your module is ACTIVE-HIGH, change this setting to false:
 */
const bool RELAY_IS_ACTIVE_LOW = true; 

// Duration in milliseconds for each test step (change this number anytime!)
const unsigned long STEP_DELAY_MS = 5000; // 5 seconds per state

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("\n\n========================================");
  Serial.println("  NodeMCU ESP8266 - 2-Channel Relay Test ");
  Serial.println("========================================");
  Serial.println("Channel 1: Pin D1 (GPIO 5)");
  Serial.println("Channel 2: Pin D2 (GPIO 4)");
  Serial.println("Mode: Active-LOW (LOW = ON, HIGH = OFF)");
  Serial.printf("Step Duration: %lu seconds\n", STEP_DELAY_MS / 1000);

  // Configure Pins
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(RELAY_PIN_2, OUTPUT);
  pinMode(ONBOARD_LED, OUTPUT);

  // Initial state: Start with both OFF
  digitalWrite(RELAY_PIN, HIGH);
  digitalWrite(RELAY_PIN_2, HIGH);
  digitalWrite(ONBOARD_LED, HIGH);

  Serial.println("[READY] Starting toggle cycle...");
  Serial.println("========================================\n");
}

void loop() {
  // Step 1: Turn Channel 1 ON
  Serial.println(">>> Channel 1 (D1) -> ON [Relay 1 CLICK & Fan SPINS]");
  digitalWrite(RELAY_PIN, LOW);
  digitalWrite(ONBOARD_LED, LOW);
  delay(STEP_DELAY_MS);

  // Step 2: Turn Channel 1 OFF, Channel 2 ON
  Serial.println(">>> Channel 1 (D1) -> OFF [Fan STOPS] | Channel 2 (D2) -> ON");
  digitalWrite(RELAY_PIN, HIGH);
  digitalWrite(RELAY_PIN_2, LOW);
  delay(STEP_DELAY_MS);

  // Step 3: Turn Both OFF
  Serial.println(">>> Both Channels -> OFF");
  digitalWrite(RELAY_PIN_2, HIGH);
  digitalWrite(ONBOARD_LED, HIGH);
  delay(STEP_DELAY_MS);
}
