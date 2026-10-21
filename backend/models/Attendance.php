<?php

require_once __DIR__ . '/../config/database.php';

class Attendance {
    private $conn;
    private $table = 'attendance';

    public function __construct() {
        $this->conn = Database::getInstance()->getConnection();
    }

    public function getToday() {
        $query = "SELECT a.*, s.student_name, s.register_number, s.department, s.section, s.year
                  FROM {$this->table} a
                  JOIN students s ON a.student_id = s.id
                  WHERE a.attendance_date = CURDATE()
                  ORDER BY a.check_in_time ASC";
        $stmt = $this->conn->prepare($query);
        $stmt->execute();
        
        return $stmt->fetchAll();
    }

    public function getByDate($date) {
        $query = "SELECT a.*, s.student_name, s.register_number, s.department, s.section, s.year
                  FROM {$this->table} a
                  JOIN students s ON a.student_id = s.id
                  WHERE a.attendance_date = :date
                  ORDER BY a.check_in_time ASC";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':date', $date);
        $stmt->execute();
        
        return $stmt->fetchAll();
    }

    public function getByStudent($studentId) {
        $query = "SELECT a.*, s.student_name, s.register_number, s.department
                  FROM {$this->table} a
                  JOIN students s ON a.student_id = s.id
                  WHERE a.student_id = :student_id
                  ORDER BY a.attendance_date DESC
                  LIMIT 30";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':student_id', $studentId, PDO::PARAM_INT);
        $stmt->execute();
        
        return $stmt->fetchAll();
    }

    public function getSummary() {
        $query = "SELECT 
                    COUNT(*) as total_students,
                    SUM(CASE WHEN status = 'present' THEN 1 ELSE 0 END) as present_count,
                    SUM(CASE WHEN status = 'absent' THEN 1 ELSE 0 END) as absent_count,
                    SUM(CASE WHEN status = 'late' THEN 1 ELSE 0 END) as late_count
                  FROM {$this->table} 
                  WHERE attendance_date = CURDATE()";
        $stmt = $this->conn->prepare($query);
        $stmt->execute();
        
        return $stmt->fetch();
    }

    public function create($studentId, $date, $checkInTime, $status, $method) {
        $query = "INSERT INTO {$this->table} 
                  (student_id, attendance_date, check_in_time, status, method) 
                  VALUES (:student_id, :attendance_date, :check_in_time, :status, :method)
                  ON DUPLICATE KEY UPDATE 
                  check_in_time = VALUES(check_in_time), status = VALUES(status), method = VALUES(method)";
        
        $stmt = $this->conn->prepare($query);
        
        $stmt->bindParam(':student_id', $studentId);
        $stmt->bindParam(':attendance_date', $date);
        $stmt->bindParam(':check_in_time', $checkInTime);
        $stmt->bindParam(':status', $status);
        $stmt->bindParam(':method', $method);
        
        return $stmt->execute();
    }
}
