# IntelliSpace Smart Campus Automation System — Backend API

A complete **PHP 8+ REST API** backend for the IntelliSpace Smart Campus Automation System. Designed to be consumed by a **Flutter mobile application**.

---

## Tech Stack

| Component       | Technology                        |
|-----------------|-----------------------------------|
| Language         | PHP 8.2+                          |
| Database         | MySQL 8.0 / MariaDB 10.5+        |
| Web Server       | Apache (XAMPP)                     |
| Architecture     | REST API (JSON)                    |
| Auth             | JWT (HMAC-SHA256)                  |
| DB Driver        | PDO with Prepared Statements       |
| CORS             | Full preflight support             |
| DB Admin         | phpMyAdmin                         |

---

## Features

- ✅ Pure PHP 8+ REST API (no heavy frameworks)
- ✅ 43+ fully functional API endpoints
- ✅ JWT-based stateless authentication
- ✅ Role-based access control (Admin / Teacher)
- ✅ PDO prepared statements (SQL injection protection)
- ✅ Password hashing with `password_hash()`
- ✅ CORS support for Flutter frontend
- ✅ Modular MVC-like project structure
- ✅ Device control audit logging
- ✅ Energy prediction algorithm (replaceable with ML)
- ✅ IoT-ready sensor data pipeline
- ✅ Consistent JSON response format

---

## Project Structure

```
backend/
├── config/
│   ├── config.php           # App and DB configuration
│   └── database.php         # PDO singleton connection
│
├── middleware/
│   ├── auth.php             # JWT authentication middleware
│   └── cors.php             # CORS headers middleware
│
├── models/
│   ├── User.php             # User CRUD operations
│   ├── Student.php          # Student queries
│   ├── Attendance.php       # Attendance CRUD + reports
│   ├── Sensor.php           # Sensor queries + status updates
│   ├── SensorReading.php    # Sensor readings CRUD
│   ├── Device.php           # Device control + audit log
│   ├── Energy.php           # Energy consumption queries
│   ├── EnergyPrediction.php # Prediction queries + creation
│   ├── Camera.php           # Camera queries
│   ├── SecurityEvent.php    # Security event CRUD
│   └── Notification.php     # Notification CRUD
│
├── controllers/
│   ├── AuthController.php        # Login / Logout / Profile
│   ├── UserController.php        # User management
│   ├── DashboardController.php   # Aggregated dashboard data
│   ├── SensorController.php      # IoT sensor data
│   ├── DeviceController.php      # Device power control
│   ├── EnergyController.php      # Energy monitoring
│   ├── PredictionController.php  # Energy predictions
│   ├── AttendanceController.php  # Biometric attendance
│   ├── CameraController.php      # Camera management
│   ├── SecurityController.php    # Security events
│   └── NotificationController.php # Notifications
│
├── routes/
│   └── api.php              # Route definitions + Router class
│
├── utils/
│   ├── JWT.php              # JWT encode/decode
│   ├── Response.php         # JSON response helpers
│   └── Validation.php       # Input validation helpers
│
├── public/
│   ├── index.php            # Application entry point
│   └── .htaccess            # Apache rewrite rules
│
├── database/
│   ├── schema.sql           # Complete database schema (12 tables)
│   └── seed.sql             # Demo data for immediate testing
│
└── README.md                # This file
```

---

## Local Development Setup (XAMPP)

### Prerequisites

- [XAMPP](https://www.apachefriends.org/) installed (Apache + MySQL + PHP)

### Step-by-Step Setup

#### 1. Start XAMPP Services

Open **XAMPP Control Panel** (`C:\xampp\xampp-control.exe`) and start:
- ✅ **Apache** (port 80)
- ✅ **MySQL** (port 3306)

#### 2. Copy Backend Files

Copy the entire `backend/` folder to your XAMPP htdocs:

```
C:\xampp\htdocs\intellispace_backend\
```

#### 3. Database Setup via phpMyAdmin

1. Open your browser → `http://localhost/phpmyadmin`
2. Click **New** (left sidebar) → Create database named `intellispace`
3. Select the `intellispace` database → click **Import** tab
4. Import `database/schema.sql` first → click **Import**
5. Import `database/seed.sql` second → click **Import**

#### 4. Configuration

Edit `config/config.php` if your MySQL credentials differ:

```php
define('DB_HOST', 'localhost');
define('DB_PORT', '3306');
define('DB_NAME', 'intellispace');
define('DB_USER', 'root');
define('DB_PASS', '');  // Default XAMPP has empty password
```

#### 5. Verify Installation

Open your browser:
```
http://localhost/intellispace_backend/public/api/auth/login
```
(You'll see a 422 error, which means the API is running!)

---

## Demo Credentials

| Role    | Email                           | Password     |
|---------|---------------------------------|--------------|
| Admin   | admin@intellispace.com          | password     |
| Teacher | sarah.jenkins@intellispace.com  | password     |

---

## Flutter Connection

In your Flutter app, configure the API base URL:

### Android Emulator
```dart
class ApiConfig {
    static const String baseUrl = 'http://10.0.2.2/intellispace_backend/public/api';
}
```

### Physical Device (same WiFi)
Find your PC's IP: run `ipconfig` in CMD, use the IPv4 address:
```dart
class ApiConfig {
    static const String baseUrl = 'http://192.168.1.100/intellispace_backend/public/api';
}
```

### Windows/Web Desktop
```dart
class ApiConfig {
    static const String baseUrl = 'http://localhost/intellispace_backend/public/api';
}
```

---

## API Endpoints Reference

### Authentication
| Method | Endpoint         | Auth | Description           |
|--------|-----------------|------|-----------------------|
| POST   | /auth/login      | ❌   | Login, get JWT token  |
| GET    | /auth/me         | ✅   | Get current user info |
| POST   | /auth/logout     | ✅   | Logout (discard token)|

### Dashboard
| Method | Endpoint    | Auth | Description                  |
|--------|------------|------|------------------------------|
| GET    | /dashboard  | ✅   | Aggregated dashboard data    |

### Users
| Method | Endpoint       | Auth  | Description            |
|--------|---------------|-------|------------------------|
| GET    | /users         | Admin | List all users         |
| GET    | /users/{id}    | ✅    | Get user by ID         |
| PUT    | /users/{id}    | ✅    | Update user profile    |

### Sensors
| Method | Endpoint                    | Auth | Description                   |
|--------|-----------------------------|------|-------------------------------|
| GET    | /sensors                    | ✅   | List all sensors              |
| GET    | /sensors/{id}               | ✅   | Get sensor by ID + reading    |
| GET    | /sensors/{id}/readings      | ✅   | Get sensor reading history    |
| POST   | /sensors/{id}/readings      | ❌*  | Post new IoT sensor reading   |
| GET    | /labs/{id}/sensors          | ✅   | Get sensors for a specific lab|

### Devices
| Method | Endpoint                   | Auth | Description              |
|--------|---------------------------|------|--------------------------|
| GET    | /devices                   | ✅   | List all devices         |
| GET    | /devices/{id}              | ✅   | Get device by ID         |
| POST   | /devices/{id}/control      | ✅   | Toggle device ON/OFF     |

### Energy
| Method | Endpoint           | Auth | Description                   |
|--------|--------------------|------|-------------------------------|
| GET    | /energy/current     | ✅   | Current total power draw (kW) |
| GET    | /energy/today       | ✅   | Today's total energy (kWh)    |
| GET    | /energy/week        | ✅   | This week's energy + breakdown|
| GET    | /energy/month       | ✅   | This month's total energy     |
| GET    | /energy/history     | ✅   | Today's hourly chart data     |
| GET    | /energy/lab/{id}    | ✅   | Energy data for a specific lab|

### Predictions
| Method | Endpoint                   | Auth  | Description                     |
|--------|---------------------------|-------|---------------------------------|
| GET    | /predictions               | ✅    | List all predictions            |
| GET    | /predictions/tomorrow      | ✅    | Tomorrow's predictions          |
| GET    | /predictions/lab/{id}      | ✅    | Predictions for a specific lab  |
| POST   | /predictions/generate      | Admin | Generate new prediction         |

### Attendance
| Method | Endpoint                     | Auth    | Description                   |
|--------|------------------------------|---------|-------------------------------|
| GET    | /attendance/summary          | ✅      | Today's attendance stats      |
| GET    | /attendance/today            | ✅      | Today's attendance records    |
| GET    | /attendance/date/{date}      | ✅      | Attendance by date            |
| GET    | /attendance/student/{id}     | ✅      | Student attendance history    |
| POST   | /attendance                  | Teacher | Mark attendance               |

### Cameras
| Method | Endpoint                | Auth | Description                    |
|--------|------------------------|------|--------------------------------|
| GET    | /cameras                | ✅   | List all cameras               |
| GET    | /cameras/{id}           | ✅   | Get camera by ID               |
| GET    | /cameras/{id}/events    | ✅   | Get events for a camera        |

### Security
| Method | Endpoint                              | Auth | Description                    |
|--------|--------------------------------------|------|--------------------------------|
| GET    | /security/events                      | ✅   | List all security events       |
| GET    | /security/events/recent               | ✅   | Recent events (limit param)    |
| POST   | /security/events                      | ❌*  | Create new security event      |
| PUT    | /security/events/{id}/acknowledge     | ✅   | Acknowledge an event           |
| PUT    | /security/events/{id}/resolve         | ✅   | Resolve an event               |

### Notifications
| Method | Endpoint                    | Auth | Description                    |
|--------|-----------------------------|------|--------------------------------|
| GET    | /notifications              | ✅   | All user notifications         |
| GET    | /notifications/unread       | ✅   | Unread notifications only      |
| PUT    | /notifications/{id}/read    | ✅   | Mark as read                   |
| PUT    | /notifications/read-all     | ✅   | Mark all as read               |
| DELETE | /notifications/{id}         | ✅   | Delete a notification          |

> *❌\* = Open for IoT devices. In production, use API keys for device auth.*

---

## API Testing Guide

### 1. Login (Get Token)

```bash
curl -X POST http://localhost/intellispace_backend/public/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@intellispace.com", "password":"password"}'
```

**Save the `token` from the response** for all subsequent requests.

### 2. Dashboard

```bash
curl -X GET http://localhost/intellispace_backend/public/api/dashboard \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

### 3. IoT Sensor Reading (ESP32 Simulation)

```bash
curl -X POST http://localhost/intellispace_backend/public/api/sensors/1/readings \
  -H "Content-Type: application/json" \
  -d '{"value": 28.5, "unit": "C"}'
```

### 4. Device Control

```bash
curl -X POST http://localhost/intellispace_backend/public/api/devices/1/control \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{"power_state": "OFF"}'
```

### 5. Mark Attendance

```bash
curl -X POST http://localhost/intellispace_backend/public/api/attendance \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{"student_id": 1, "attendance_date": "2026-09-24", "check_in_time": "09:03:00", "status": "present", "method": "biometric"}'
```

### 6. Security Event (AI Camera Simulation)

```bash
curl -X POST http://localhost/intellispace_backend/public/api/security/events \
  -H "Content-Type: application/json" \
  -d '{"camera_id": 1, "event_type": "unauthorized_movement", "location": "Lab 3", "description": "Person detected in restricted area", "severity": "high"}'
```

---

## Response Format

### Success
```json
{
    "success": true,
    "message": "Data retrieved successfully",
    "data": { ... }
}
```

### Error
```json
{
    "success": false,
    "message": "Invalid credentials"
}
```

### HTTP Status Codes Used
| Code | Meaning            |
|------|--------------------|
| 200  | OK                 |
| 201  | Created            |
| 400  | Bad Request        |
| 401  | Unauthorized       |
| 403  | Forbidden          |
| 404  | Not Found          |
| 422  | Validation Error   |
| 500  | Server Error       |

---

## Database Tables

| # | Table               | Description                         |
|---|---------------------|-------------------------------------|
| 1 | users               | Admin and teacher accounts          |
| 2 | students            | Student records                     |
| 3 | labs                | Physical lab rooms                  |
| 4 | sensors             | IoT sensors in labs                 |
| 5 | sensor_readings     | Historical sensor data              |
| 6 | devices             | Controllable appliances             |
| 7 | device_logs         | Device action audit trail           |
| 8 | energy_consumption  | Historical power/energy data        |
| 9 | energy_predictions  | ML-generated energy forecasts       |
| 10| attendance          | Daily student check-ins             |
| 11| cameras             | Surveillance cameras                |
| 12| security_events     | AI-detected security incidents      |
| 13| notifications       | In-app user notifications           |

---

## IoT Data Flow Architecture

```
ESP32 / IoT Sensor
        ↓
POST /api/sensors/{id}/readings
        ↓
PHP REST API (validate → store → update status)
        ↓
MySQL Database
        ↓
GET /api/sensors, /api/dashboard
        ↓
Flutter Mobile App
```

---

## Security Implementation

- ✅ PDO prepared statements (SQL injection prevention)
- ✅ `password_hash()` / `password_verify()` for passwords
- ✅ JWT tokens with HMAC-SHA256 signature verification
- ✅ Token expiration (24 hours)
- ✅ Role-based endpoint protection
- ✅ Input validation on all POST/PUT endpoints
- ✅ No password fields exposed in API responses
- ✅ CORS preflight handling
- ✅ Device action audit logging

---

## License

Built for the IntelliSpace Smart Campus Automation System — Mini Project.
