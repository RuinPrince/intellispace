-- =========================================================
-- IntelliSpace Smart Campus Automation System
-- Database Seed Data v2.2
-- Modified Specification: Seed single default lab with 1 Fan & 1 Light
-- =========================================================

USE intellispace;

-- 1. Users
INSERT INTO users (id, name, email, password, role, department) VALUES
(1, 'Admin User', 'admin@intellispace.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin', 'Computer Science & Engineering'),
(2, 'Dr. Sarah Jenkins', 'sarah@intellispace.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'teacher', 'Information Technology')
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- 2. Students (Actual roll numbers: 235025 and 235014)
INSERT INTO students (id, student_name, register_number, department, year, section, email) VALUES
(1, 'Madhankumar E G D', '235025', 'Information Technology', 3, 'A', 'edgmadhankumar@gmail.com'),
(2, 'Aravindsamy P', '235014', 'Information Technology', 3, 'A', 'pmaha0896@gmail.com')
ON DUPLICATE KEY UPDATE student_name=VALUES(student_name);

-- 3. Default Single Lab ("Lab 1")
INSERT INTO labs (id, lab_name, building, floor, room_number, description) VALUES
(1, 'Lab 1', 'Tech Innovation Center', '2nd Floor', 'TIC-204', 'Default Automation Lab')
ON DUPLICATE KEY UPDATE lab_name=VALUES(lab_name);

-- 4. Devices (Exactly 1 Fan and 1 Light)
INSERT INTO devices (id, device_name, device_type, lab_id, device_identifier, status, power_state) VALUES
(1, 'Main Ceiling Lights', 'light', 1, 'DEV_LIGHT_01', 'online', 'ON'),
(4, 'Exhaust Ventilation Fan', 'fan', 1, 'DEV_FAN_01', 'online', 'ON')
ON DUPLICATE KEY UPDATE device_name=VALUES(device_name);

-- 5. Audit Log Entry
INSERT INTO device_logs (device_id, action, performed_by, old_state, new_state) VALUES
(1, 'boot_sync', 1, 'OFF', 'ON'),
(4, 'boot_sync', 1, 'OFF', 'ON');

-- 6. Attendance Today
INSERT INTO attendance (student_id, attendance_date, check_in_time, status, method) VALUES
(1, CURRENT_DATE(), '08:45:00', 'present', 'biometric'),
(2, CURRENT_DATE(), '08:52:00', 'present', 'biometric')
ON DUPLICATE KEY UPDATE status=VALUES(status);

-- 7. Notifications (Device and Attendance)
INSERT INTO notifications (user_id, notification_type, title, message, severity) VALUES
(1, 'system', 'IntelliSpace System Active', 'IntelliSpace is connected to database.', 'info'),
(1, 'device', 'Hardware Node Connected', 'ESP8266 NodeMCU is active and polling device states every 1.5s.', 'info'),
(1, 'attendance', 'Attendance Synchronized', 'Student attendance records synced successfully.', 'info');
