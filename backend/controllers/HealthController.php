<?php

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../utils/Response.php';

class HealthController {
    public function check() {
        try {
            $db = Database::getInstance()->getConnection();
            $stmt = $db->query('SELECT COUNT(*) as user_count FROM users');
            $result = $stmt->fetch();
            
            Response::json([
                'status' => 'healthy',
                'database' => 'connected',
                'users_count' => (int)$result['user_count'],
                'server_time' => date('Y-m-d H:i:s'),
                'php_version' => PHP_VERSION
            ], 'System is online and connected to database.');
        } catch (Exception $e) {
            Response::error('Database connection error: ' . $e->getMessage(), 500);
        }
    }
}
