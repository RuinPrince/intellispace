-- =========================================================
-- IntelliSpace Smart Campus Automation System
-- Supabase PostgreSQL Schema & Seed Migration Script (v2.2)
-- Modified Specification: Cleaned schema (IoT, Energy, Security removed)
-- Default Seed: Single Lab ("Lab 1") with 1 Fan & 1 Light
-- =========================================================

-- Enable UUID extension if needed
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop removed legacy tables if they exist
DROP TABLE IF EXISTS security_events CASCADE;
DROP TABLE IF EXISTS cameras CASCADE;
DROP TABLE IF EXISTS energy_predictions CASCADE;
DROP TABLE IF EXISTS energy_consumption CASCADE;
DROP TABLE IF EXISTS sensor_readings CASCADE;
DROP TABLE IF EXISTS sensors CASCADE;

-- =========================================================
-- 1. Users Table
-- =========================================================
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'teacher' CHECK (role IN ('admin', 'teacher')),
    department VARCHAR(100),
    profile_image VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =========================================================
-- 2. Students Table
-- =========================================================
CREATE TABLE IF NOT EXISTS students (
    id SERIAL PRIMARY KEY,
    student_name VARCHAR(255) NOT NULL,
    register_number VARCHAR(50) NOT NULL UNIQUE,
    department VARCHAR(100) NOT NULL,
    year INT NOT NULL,
    section VARCHAR(10) NOT NULL,
    email VARCHAR(255) UNIQUE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =========================================================
-- 3. Labs Table
-- =========================================================
CREATE TABLE IF NOT EXISTS labs (
    id SERIAL PRIMARY KEY,
    lab_name VARCHAR(100) NOT NULL,
    building VARCHAR(100) NOT NULL,
    floor VARCHAR(50) NOT NULL,
    room_number VARCHAR(50) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =========================================================
-- 4. Devices Table (Only Fans & Lights per Modified Spec)
-- =========================================================
CREATE TABLE IF NOT EXISTS devices (
    id SERIAL PRIMARY KEY,
    device_name VARCHAR(100) NOT NULL,
    device_type VARCHAR(50) NOT NULL CHECK (device_type IN ('light', 'fan')),
    lab_id INT REFERENCES labs(id) ON DELETE CASCADE,
    device_identifier VARCHAR(100) UNIQUE,
    status VARCHAR(20) DEFAULT 'offline' CHECK (status IN ('online', 'offline')),
    power_state VARCHAR(10) DEFAULT 'OFF' CHECK (power_state IN ('ON', 'OFF')),
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =========================================================
-- 5. Device Logs Table (Audit Logging)
-- =========================================================
CREATE TABLE IF NOT EXISTS device_logs (
    id BIGSERIAL PRIMARY KEY,
    device_id INT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL,
    performed_by INT REFERENCES users(id) ON DELETE SET NULL,
    old_state VARCHAR(20),
    new_state VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_device_logs_device_id ON device_logs(device_id);
CREATE INDEX IF NOT EXISTS idx_device_logs_created_at ON device_logs(created_at DESC);

-- =========================================================
-- 6. Attendance Table
-- =========================================================
CREATE TABLE IF NOT EXISTS attendance (
    id BIGSERIAL PRIMARY KEY,
    student_id INT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL,
    check_in_time TIME,
    status VARCHAR(20) NOT NULL CHECK (status IN ('present', 'absent', 'late')),
    method VARCHAR(20) NOT NULL DEFAULT 'biometric' CHECK (method IN ('biometric', 'manual')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_daily_attendance UNIQUE (student_id, attendance_date)
);

CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance(attendance_date);
CREATE INDEX IF NOT EXISTS idx_attendance_student ON attendance(student_id);

-- =========================================================
-- 7. Notifications Table (Attendance & Device Only)
-- =========================================================
CREATE TABLE IF NOT EXISTS notifications (
    id BIGSERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    notification_type VARCHAR(50) NOT NULL CHECK (notification_type IN ('device', 'attendance', 'system')),
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    severity VARCHAR(20) DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'critical')),
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =========================================================
-- Enable Row Level Security (RLS) & Allow Read/Write
-- =========================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE labs ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
    tbl text;
BEGIN
    FOR tbl IN SELECT tablename FROM pg_tables WHERE schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS "Public access policy" ON %I;', tbl);
        EXECUTE format('CREATE POLICY "Public access policy" ON %I FOR ALL USING (true) WITH CHECK (true);', tbl);
    END LOOP;
END $$;

-- Enable Realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE devices;
ALTER PUBLICATION supabase_realtime ADD TABLE device_logs;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- =========================================================
-- INITIAL SEED DATA
-- =========================================================

-- 1. Default Admin & Teacher
INSERT INTO users (id, name, email, password, role, department) VALUES
(1, 'Admin User', 'admin@intellispace.com', 'password', 'admin', 'Computer Science & Engineering'),
(2, 'Dr. Sarah Jenkins', 'sarah@intellispace.com', 'password', 'teacher', 'Information Technology')
ON CONFLICT (email) DO NOTHING;

-- 2. Default Single Lab ("Lab 1")
INSERT INTO labs (id, lab_name, building, floor, room_number, description) VALUES
(1, 'Lab 1', 'Tech Innovation Center', '2nd Floor', 'TIC-204', 'Default Automation & Robotics Lab')
ON CONFLICT (id) DO UPDATE SET lab_name = EXCLUDED.lab_name;

-- 3. Connected Hardware Devices (Exactly 1 Fan and 1 Light in Lab 1)
-- Device 1: Main Ceiling Lights -> NodeMCU Relay Channel 2 (Pin D2)
-- Device 4: Exhaust Ventilation Fan -> NodeMCU Relay Channel 1 (Pin D1)
INSERT INTO devices (id, device_name, device_type, lab_id, device_identifier, status, power_state) VALUES
(1, 'Main Ceiling Lights', 'light', 1, 'DEV_LIGHT_01', 'online', 'ON'),
(4, 'Exhaust Ventilation Fan', 'fan', 1, 'DEV_FAN_01', 'online', 'ON')
ON CONFLICT (id) DO UPDATE SET device_name = EXCLUDED.device_name, device_type = EXCLUDED.device_type, lab_id = EXCLUDED.lab_id;

-- 4. Initial Audit Log
INSERT INTO device_logs (device_id, action, performed_by, old_state, new_state) VALUES
(1, 'boot_sync', 1, 'OFF', 'ON'),
(4, 'boot_sync', 1, 'OFF', 'ON');

-- 5. Students (Actual roll numbers: 235025 and 235014)
INSERT INTO students (id, student_name, register_number, department, year, section, email) VALUES
(1, 'Madhankumar E G D', '235025', 'Information Technology', 3, 'A', 'edgmadhankumar@gmail.com'),
(2, 'Aravindsamy P', '235014', 'Information Technology', 3, 'A', 'pmaha0896@gmail.com')
ON CONFLICT (register_number) DO NOTHING;

-- 6. Attendance Today
INSERT INTO attendance (student_id, attendance_date, check_in_time, status, method) VALUES
(1, CURRENT_DATE, '08:45:00', 'present', 'biometric'),
(2, CURRENT_DATE, '08:52:00', 'present', 'biometric')
ON CONFLICT (student_id, attendance_date) DO NOTHING;

-- 7. Notifications (Device & Attendance only)
INSERT INTO notifications (user_id, notification_type, title, message, severity) VALUES
(1, 'system', 'IntelliSpace Cloud Live', 'Your system is connected to Supabase Cloud PostgreSQL.', 'info'),
(1, 'device', 'Hardware Node Connected', 'ESP8266 NodeMCU is actively polling device states.', 'info'),
(1, 'attendance', 'Attendance Synchronized', 'Today\'s biometric check-ins recorded successfully.', 'info');
