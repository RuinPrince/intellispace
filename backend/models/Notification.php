<?php

require_once __DIR__ . '/../config/database.php';

class Notification {
    private $conn;
    private $table = 'notifications';

    public function __construct() {
        $this->conn = Database::getInstance()->getConnection();
    }

    public function getByUser($userId) {
        $query = "SELECT * FROM {$this->table} WHERE user_id = :user_id ORDER BY created_at DESC";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':user_id', $userId);
        $stmt->execute();
        
        return $stmt->fetchAll();
    }

    public function getUnread($userId) {
        $query = "SELECT * FROM {$this->table} WHERE user_id = :user_id AND is_read = FALSE ORDER BY created_at DESC";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':user_id', $userId);
        $stmt->execute();
        
        return $stmt->fetchAll();
    }

    public function create($userId, $type, $title, $message, $severity) {
        $query = "INSERT INTO {$this->table} (user_id, notification_type, title, message, severity) 
                  VALUES (:user_id, :type, :title, :message, :severity)";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':user_id', $userId);
        $stmt->bindParam(':type', $type);
        $stmt->bindParam(':title', $title);
        $stmt->bindParam(':message', $message);
        $stmt->bindParam(':severity', $severity);
        
        return $stmt->execute();
    }

    public function markRead($id, $userId) {
        $query = "UPDATE {$this->table} SET is_read = TRUE WHERE id = :id AND user_id = :user_id";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':id', $id);
        $stmt->bindParam(':user_id', $userId);
        
        return $stmt->execute();
    }

    public function markAllRead($userId) {
        $query = "UPDATE {$this->table} SET is_read = TRUE WHERE user_id = :user_id AND is_read = FALSE";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':user_id', $userId);
        
        return $stmt->execute();
    }

    public function delete($id, $userId) {
        $query = "DELETE FROM {$this->table} WHERE id = :id AND user_id = :user_id";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':id', $id);
        $stmt->bindParam(':user_id', $userId);
        
        return $stmt->execute();
    }
}
