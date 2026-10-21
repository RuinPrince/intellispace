# 🔌 IntelliSpace Hardware Node Guide (ESP8266 NodeMCU)

> **Welcome!** This guide provides clear, step-by-step instructions for wiring and running the ESP8266 NodeMCU hardware node with a 2-channel relay module for fan and light control under the **IntelliSpace** system.

---

## 🏛️ System Overview

The hardware node connects physical appliances to the IntelliSpace system:
* **Cloud Sync:** The ESP8266 NodeMCU connects to Wi-Fi and polls device states from Supabase Cloud PostgreSQL every **1.5 seconds**.
* **Relay Channel 1 (Pin D1 / GPIO 5):** Controls the **5V DC Exhaust Ventilation Fan** (App Device ID: 4).
* **Relay Channel 2 (Pin D2 / GPIO 4):** Controls the **5V Ceiling Light / LED** (App Device ID: 1).
* **Emergency Fallback (Port 80):** Embedded local HTTP server running at `http://<NodeMCU_IP>` allows direct browser control over local Wi-Fi even without cloud access.
* **Streamlined Firmware:** Telemetry pushing (energy/temperature) has been completely removed in accordance with the Modified Specification.

---

## 🧰 Required Components

1. **ESP8266 NodeMCU** (Amica, CP2102, or CH340 board)
2. **2-Channel 5V Relay Module** (Active-LOW Songle relay module)
3. **5V DC Fan** (Red `+` wire and Black `-` wire)
4. **5V LED Light Module** (`+` and `-` terminals)
5. **Jumper Wires** (Female-to-Female and Male-to-Female)
6. **Micro-USB Cable** (Connected to laptop or 5V 2A USB power adapter)

---

## 📌 Pinout & Wiring Connections

### 1. NodeMCU to 2-Channel Relay Board

| NodeMCU Pin | Relay Board Pin | Function |
|---|---|---|
| **Vin (5V)** / **VU** | **VCC** | 5V DC relay module power |
| **GND** | **GND** | Ground reference |
| **D2 (GPIO 4)** | **IN (Fan)** | Fan control signal |
| **D1 (GPIO 5)** | **IN (Aux / Light)** | Optional auxiliary / light signal |

*(Note: Most Songle relay modules are Active-LOW: driving the pin LOW turns the relay ON).*

---

### 2. Fan Circuit (Controlled by Pin D2)

* Connect a jumper wire from NodeMCU **Vin** (or **VU**) $\rightarrow$ Relay **COM** (Middle terminal).
* Connect the **Fan's RED wire (+)** $\rightarrow$ Relay **NO** (Normally Open terminal).
* Connect the **Fan's BLACK wire (-)** $\rightarrow$ NodeMCU **GND**.

> ⚠️ **Important:** Connect the positive wire to **NO** (Normally Open). Connecting to NC (Normally Closed) keeps the fan spinning continuously!

---

## 📋 Complete Wiring Schematic

```text
[NodeMCU Vin / VU]  ----->  Relay VCC
[NodeMCU GND]       ----->  Relay GND
[NodeMCU D2]        ----->  Relay IN (Fan control signal)

[NodeMCU Vin / VU]  ----->  Relay COM  -->  Relay NO  -->  Fan RED (+)
[NodeMCU GND]       ------------------------------------>  Fan BLACK (-)
```

---

## 💻 Flashing Firmware to ESP8266

1. Open **Arduino IDE**.
2. Open `hardware/esp8266_firmware/esp8266_firmware.ino`.
3. In lines 27–28, set your Wi-Fi credentials (must be a 2.4 GHz network or mobile hotspot):
   ```cpp
   const char* WIFI_SSID     = "Your_WiFi_Name";
   const char* WIFI_PASSWORD = "Your_WiFi_Password";
   ```
4. Verify board settings:
   * **Tools $\rightarrow$ Board $\rightarrow$ ESP8266 Boards $\rightarrow$ NodeMCU 1.0 (ESP-12E Module)**.
   * **Tools $\rightarrow$ Port** $\rightarrow$ Select your active COM port.
5. Click **Upload (➔)** and wait for "Done uploading".

---

## 🧪 Testing & Operation

### 1. Boot Self-Test
When powered on, the firmware executes a hardware self-test:
* Fan Relay clicks ON for 1.2s then OFF.
* Light Relay clicks ON for 1.2s then OFF.
* Built-in LED on D4 turns solid once Wi-Fi connects.

### 2. Cloud Control (Mobile App)
* Open the **IntelliSpace** Flutter mobile app.
* Tap **Lab Control** on the bottom navigation bar.
* Toggle **"Exhaust Ventilation Fan"** or **"Main Ceiling Lights"**.
* Within 1.5 seconds, the ESP8266 polls the new state and toggles the corresponding relay.

### 3. Emergency Local Web Server Fallback (Port 80)
If the cloud or internet is temporarily unavailable:
* Ensure your phone/PC is on the same local Wi-Fi network as the ESP8266.
* Open your browser and navigate to:
  ```text
  http://<NodeMCU_IP_Address>
  ```
* The embedded web page displays direct toggle buttons for **Exhaust Fan** and **Ceiling Lights** with immediate relay switching.

---

## ❓ Troubleshooting

| Issue | Solution |
|---|---|
| **Fan runs non-stop on power-on** | Ensure the Fan Red wire is in terminal **NO** (Normally Open), not NC. |
| **Relays do not click** | Check Vin to VCC and GND to GND jumper wires. Ensure USB provides 5V. |
| **Wi-Fi connection fails** | Ensure network is **2.4 GHz** (ESP8266 does not support 5 GHz). Check SSID/password. |
| **Relay logic inverted** | Set `const bool RELAY_ACTIVE_LOW = false;` in line 49 if your module triggers on HIGH. |
