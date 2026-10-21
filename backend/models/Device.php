<?php

require_once __DIR__ . '/../config/database.php';

class Device {
    private $conn;
    private $table = 'devices';

    public function __construct() {
        $this->conn = Database::getInstance()->getConnection();
    }

    public function getAll() {
        $query = "SELECT d.*, l.lab_name 
                  FROM {$this->table} d
                  LEFT JOIN labs l ON d.lab_id = l.id
                  ORDER BY l.lab_name ASC, d.device_name ASC";
        $stmt = $this->conn->prepare($query);
        $stmt->execute();
        
        return $stmt->fetchAll();
    }

    public function findById($id) {
        $query = "SELECT d.*, l.lab_name 
                  FROM {$this->table} d
                  LEFT JOIN labs l ON d.lab_id = l.id
                  WHERE d.id = :id LIMIT 1";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':id', $id);
        $stmt->execute();
        
        return $stmt->fetch();
    }

    public function updatePowerState($id, $state) {
        $query = "UPDATE {$this->table} SET power_state = :state, last_updated = CURRENT_TIMESTAMP WHERE id = :id";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':state', $state);
        $stmt->bindParam(':id', $id);
        
        return $stmt->execute();
    }

    /**
     * Log a device state change for audit trail.
     */
    public function logAction($deviceId, $action, $userId, $oldState, $newState) {
        $query = "INSERT INTO device_logs (device_id, action, performed_by, old_state, new_state) 
                  VALUES (:device_id, :action, :performed_by, :old_state, :new_state)";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':device_id', $deviceId);
        $stmt->bindParam(':action', $action);
        $stmt->bindParam(':performed_by', $userId);
        $stmt->bindParam(':old_state', $oldState);
        $stmt->bindParam(':new_state', $newState);
        
        return $stmt->execute();
    }
}
