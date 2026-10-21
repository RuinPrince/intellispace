-- =========================================================
-- IntelliSpace Smart Campus Automation System
-- Database Schema v2.2 (MySQL 8.0+ / MariaDB 10.5+)
-- Cleaned schema (IoT, Energy, Security removed)
-- Default Seed: Single Lab ("Lab 1") with 1 Fan & 1 Light
-- =========================================================

CREATE DATABASE IF NOT EXISTS intellispace CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE intellispace;

-- Drop removed legacy tables
DROP TABLE IF EXISTS security_events;
DROP TABLE IF EXISTS cameras;
DROP TABLE IF EXISTS energy_predictions;
DROP TABLE IF EXISTS energy_consumption;
DROP TABLE IF EXISTS sensor_readings;
DROP TABLE IF EXISTS sensors;

-- =========================================================
-- 1. Users Table
-- =========================================================
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role ENUM('admin', 'teacher') NOT NULL DEFAULT 'teacher',
    department VARCHAR(100),
    profile_image VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- =========================================================
-- 2. Students Table
-- =========================================================
CREATE TABLE IF NOT EXISTS students (
    id INT AUTO_INCREMENT PRIMARY KEY,
    student_name VARCHAR(255) NOT NULL,
    register_number VARCHAR(50) NOT NULL UNIQUE,
    department VARCHAR(100) NOT NULL,
    year INT NOT NULL,
    section VARCHAR(10) NOT NULL,
    email VARCHAR(255) UNIQUE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- =========================================================
-- 3. Labs Table
-- =========================================================
CREATE TABLE IF NOT EXISTS labs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    lab_name VARCHAR(100) NOT NULL,
    building VARCHAR(100) NOT NULL,
    floor VARCHAR(50) NOT NULL,
    room_number VARCHAR(50) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- =========================================================
-- 4. Devices Table (Fans & Lights only)
-- =========================================================
CREATE TABLE IF NOT EXISTS devices (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_name VARCHAR(100) NOT NULL,
    device_type ENUM('light', 'fan') NOT NULL,
    lab_id INT,
    device_identifier VARCHAR(100) UNIQUE,
    status ENUM('online', 'offline') DEFAULT 'offline',
    power_state ENUM('ON', 'OFF') DEFAULT 'OFF',
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (lab_id) REFERENCES labs(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- 5. Device Logs Table (Audit Logging)
-- =========================================================
CREATE TABLE IF NOT EXISTS device_logs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    device_id INT NOT NULL,
    action VARCHAR(50) NOT NULL,
    performed_by INT,
    old_state VARCHAR(20),
    new_state VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    FOREIGN KEY (performed_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE INDEX idx_device_logs_device_id ON device_logs(device_id);
CREATE INDEX idx_device_logs_created_at ON device_logs(created_at DESC);

-- =========================================================
-- 6. Attendance Table
-- =========================================================
CREATE TABLE IF NOT EXISTS attendance (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    attendance_date DATE NOT NULL,
    check_in_time TIME,
    status ENUM('present', 'absent', 'late') NOT NULL,
    method ENUM('biometric', 'manual') NOT NULL DEFAULT 'biometric',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
    UNIQUE KEY unique_daily_attendance (student_id, attendance_date)
) ENGINE=InnoDB;

CREATE INDEX idx_attendance_date ON attendance(attendance_date);
CREATE INDEX idx_attendance_student ON attendance(student_id);

-- =========================================================
-- 7. Notifications Table
-- =========================================================
CREATE TABLE IF NOT EXISTS notifications (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    notification_type ENUM('device', 'attendance', 'system') NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    severity ENUM('info', 'warning', 'critical') DEFAULT 'info',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- SEED DATA (Default Single Lab with 1 Fan & 1 Light)
-- =========================================================
INSERT INTO users (id, name, email, password, role, department) VALUES
(1, 'Admin User', 'admin@intellispace.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin', 'Computer Science & Engineering'),
(2, 'Dr. Sarah Jenkins', 'sarah@intellispace.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'teacher', 'Information Technology')
ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO labs (id, lab_name, building, floor, room_number, description) VALUES
(1, 'Lab 1', 'Tech Innovation Center', '2nd Floor', 'TIC-204', 'Default Automation Lab')
ON DUPLICATE KEY UPDATE lab_name=VALUES(lab_name);

INSERT INTO devices (id, device_name, device_type, lab_id, device_identifier, status, power_state) VALUES
(1, 'Main Ceiling Lights', 'light', 1, 'DEV_LIGHT_01', 'online', 'ON'),
(4, 'Exhaust Ventilation Fan', 'fan', 1, 'DEV_FAN_01', 'online', 'ON')
ON DUPLICATE KEY UPDATE device_name=VALUES(device_name);

INSERT INTO students (id, student_name, register_number, department, year, section, email) VALUES
(1, 'Madhankumar E G D', '235025', 'Information Technology', 3, 'A', 'edgmadhankumar@gmail.com'),
(2, 'Aravindsamy P', '235014', 'Information Technology', 3, 'A', 'pmaha0896@gmail.com')
ON DUPLICATE KEY UPDATE student_name=VALUES(student_name);

INSERT INTO notifications (user_id, notification_type, title, message, severity) VALUES
(1, 'system', 'IntelliSpace Online', 'Your system is connected to database.', 'info'),
(1, 'device', 'Hardware Node Connected', 'ESP8266 NodeMCU is active.', 'info');
