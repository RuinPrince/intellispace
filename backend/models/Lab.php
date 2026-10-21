<?php

require_once __DIR__ . '/../config/database.php';

class Lab {
    private $conn;
    private $table = 'labs';

    public function __construct() {
        $this->conn = Database::getInstance()->getConnection();
    }

    public function getAll() {
        $query = "SELECT l.*, 
                         COUNT(d.id) as device_count,
                         SUM(CASE WHEN d.power_state = 'ON' THEN 1 ELSE 0 END) as active_devices
                  FROM {$this->table} l
                  LEFT JOIN devices d ON l.id = d.lab_id
                  GROUP BY l.id
                  ORDER BY l.id ASC";
        $stmt = $this->conn->prepare($query);
        $stmt->execute();
        return $stmt->fetchAll();
    }

    public function findById($id) {
        $query = "SELECT * FROM {$this->table} WHERE id = :id LIMIT 1";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':id', $id);
        $stmt->execute();
        return $stmt->fetch();
    }

    public function create($data) {
        $query = "INSERT INTO {$this->table} (lab_name, building, floor, room_number, description)
                  VALUES (:lab_name, :building, :floor, :room_number, :description)";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':lab_name', $data['lab_name']);
        $stmt->bindParam(':building', $data['building']);
        $stmt->bindParam(':floor', $data['floor']);
        $stmt->bindParam(':room_number', $data['room_number']);
        $desc = $data['description'] ?? '';
        $stmt->bindParam(':description', $desc);
        
        if ($stmt->execute()) {
            return $this->conn->lastInsertId();
        }
        return false;
    }

    public function delete($id) {
        // First delete attached devices
        $delDev = $this->conn->prepare("DELETE FROM devices WHERE lab_id = :id");
        $delDev->bindParam(':id', $id);
        $delDev->execute();

        $query = "DELETE FROM {$this->table} WHERE id = :id";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':id', $id);
        return $stmt->execute();
    }
}
