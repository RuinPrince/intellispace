<?php

require_once __DIR__ . '/../models/Attendance.php';
require_once __DIR__ . '/../models/Student.php';
require_once __DIR__ . '/../utils/Response.php';
require_once __DIR__ . '/../utils/Validation.php';
require_once __DIR__ . '/../middleware/auth.php';

class AttendanceController {
    private $attendanceModel;

    public function __construct() {
        $this->attendanceModel = new Attendance();
    }

    public function summary() {
        AuthMiddleware::authenticate();
        $summary = $this->attendanceModel->getSummary();
        
        // Calculate percentage
        $total = (int)$summary['total_students'];
        if ($total === 0) {
            $studentModel = new Student();
            $allStudents = $studentModel->getAll();
            $total = count($allStudents);
            $percentage = $total > 0 ? 0.0 : 0;
            $summary['total_students'] = $total;
            $summary['present_count'] = 0;
            $summary['absent_count'] = 0;
            $summary['late_count'] = 0;
        } else {
            $present = (int)$summary['present_count'];
            $late = (int)$summary['late_count'];
            $percentage = round((($present + $late) / $total) * 100, 2);
        }
        
        $summary['percentage'] = $percentage;
        Response::json($summary);
    }

    public function today() {
        AuthMiddleware::authenticate();
        $records = $this->attendanceModel->getToday();
        Response::json($records);
    }

    public function byDate($date) {
        AuthMiddleware::authenticate();
        
        // Validate date format (YYYY-MM-DD)
        if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
            Response::error('Invalid date format. Use YYYY-MM-DD.', 422);
        }
        
        $records = $this->attendanceModel->getByDate($date);
        Response::json($records);
    }

    public function byStudent($id) {
        AuthMiddleware::authenticate();
        
        if (!is_numeric($id) || $id <= 0) {
            Response::error('Invalid student ID', 422);
        }
        
        $records = $this->attendanceModel->getByStudent($id);
        Response::json($records);
    }

    public function store() {
        $user = AuthMiddleware::authenticate();
        
        // Both admin and teacher can mark attendance
        if (!in_array($user['role'], ['admin', 'teacher'])) {
            Response::error('Forbidden', 403);
        }
        
        $validation = Validation::required(['student_id', 'attendance_date', 'status'], $_POST);
        if ($validation !== true) {
            Response::error('Validation failed', 422, $validation);
        }
        
        $studentId = $_POST['student_id'];
        $date = $_POST['attendance_date'];
        $status = $_POST['status'];
        $method = isset($_POST['method']) ? $_POST['method'] : 'manual';
        $checkInTime = isset($_POST['check_in_time']) ? $_POST['check_in_time'] : date('H:i:s');
        
        if (!Validation::in($status, ['present', 'absent', 'late'])) {
            Response::error('Invalid status. Must be present, absent, or late.', 422);
        }
        
        if (!Validation::in($method, ['biometric', 'manual'])) {
            Response::error('Invalid method. Must be biometric or manual.', 422);
        }
        
        // Validate date format
        if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
            Response::error('Invalid date format. Use YYYY-MM-DD.', 422);
        }
        
        $success = $this->attendanceModel->create($studentId, $date, $checkInTime, $status, $method);
        
        if ($success) {
            Response::json([
                'student_id' => $studentId, 
                'attendance_date' => $date,
                'status' => $status,
                'method' => $method
            ], 'Attendance marked successfully', 201);
        } else {
            Response::error('Failed to mark attendance', 500);
        }
    }
}
