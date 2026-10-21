<?php

require_once __DIR__ . '/../config/database.php';

class User {
    private $conn;
    private $table = 'users';

    public function __construct() {
        $this->conn = Database::getInstance()->getConnection();
    }

    public function findByEmail($email) {
        $query = "SELECT * FROM {$this->table} WHERE email = :email LIMIT 1";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':email', $email);
        $stmt->execute();
        
        return $stmt->fetch();
    }

    public function findById($id) {
        $query = "SELECT id, name, email, role, department, profile_image, is_active, created_at, updated_at 
                  FROM {$this->table} WHERE id = :id LIMIT 1";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':id', $id);
        $stmt->execute();
        
        return $stmt->fetch();
    }

    public function getAll() {
        $query = "SELECT id, name, email, role, department, profile_image, is_active, created_at 
                  FROM {$this->table} ORDER BY id ASC";
        $stmt = $this->conn->prepare($query);
        $stmt->execute();
        
        return $stmt->fetchAll();
    }

    public function create($data) {
        $query = "INSERT INTO {$this->table} (name, email, password, role, department)
                  VALUES (:name, :email, :password, :role, :department)";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':name', $data['name']);
        $stmt->bindParam(':email', $data['email']);
        $password = password_hash($data['password'] ?? 'password', PASSWORD_DEFAULT);
        $stmt->bindParam(':password', $password);
        $role = $data['role'] ?? 'teacher';
        $stmt->bindParam(':role', $role);
        $dept = $data['department'] ?? '';
        $stmt->bindParam(':department', $dept);

        if ($stmt->execute()) {
            return $this->conn->lastInsertId();
        }
        return false;
    }

    public function update($id, $data) {
        $allowedFields = ['name', 'email', 'role', 'department', 'profile_image'];
        $setClauses = [];
        $params = [':id' => $id];

        foreach ($allowedFields as $field) {
            if (isset($data[$field])) {
                $setClauses[] = "{$field} = :{$field}";
                $params[":{$field}"] = $data[$field];
            }
        }

        // Handle password update
        if (!empty($data['password'])) {
            $setClauses[] = "password = :password";
            $params[':password'] = password_hash($data['password'], PASSWORD_DEFAULT);
        }

        if (empty($setClauses)) {
            return false;
        }

        $query = "UPDATE {$this->table} SET " . implode(', ', $setClauses) . " WHERE id = :id";
        $stmt = $this->conn->prepare($query);
        
        return $stmt->execute($params);
    }

    public function delete($id) {
        $query = "DELETE FROM {$this->table} WHERE id = :id";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':id', $id);
        return $stmt->execute();
    }
}
