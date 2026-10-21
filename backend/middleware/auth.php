<?php

require_once __DIR__ . '/../utils/JWT.php';
require_once __DIR__ . '/../utils/Response.php';

class AuthMiddleware {
    public static function authenticate() {
        $headers = getallheaders();
        $authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : (isset($headers['authorization']) ? $headers['authorization'] : null);
        
        if (!$authHeader) {
            Response::error('No authorization token provided', 401);
        }
        
        list($jwt) = sscanf($authHeader, 'Bearer %s');
        
        if (!$jwt) {
            Response::error('Invalid authorization header format', 401);
        }
        
        $payload = JWT::decode($jwt);
        
        if (!$payload) {
            Response::error('Invalid or expired token', 401);
        }
        
        // Return the user data contained in the token
        return $payload['user'];
    }

    public static function requireRole($role) {
        $user = self::authenticate();
        
        if ($user['role'] !== $role) {
            Response::error('Forbidden: Requires ' . $role . ' role', 403);
        }
        
        return $user;
    }
}
