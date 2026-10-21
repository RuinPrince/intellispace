<?php

require_once __DIR__ . '/../models/User.php';
require_once __DIR__ . '/../utils/JWT.php';
require_once __DIR__ . '/../utils/Response.php';
require_once __DIR__ . '/../utils/Validation.php';
require_once __DIR__ . '/../middleware/auth.php';

class AuthController {
    public function login() {
        $validation = Validation::required(['email', 'password'], $_POST);
        
        if ($validation !== true) {
            Response::error('Validation failed', 422, $validation);
        }
        
        $email = $_POST['email'];
        $password = $_POST['password'];
        
        $userModel = new User();
        $user = $userModel->findByEmail($email);
        
        if (!$user || !password_verify($password, $user['password'])) {
            Response::error('Invalid credentials', 401);
        }
        
        if (!$user['is_active']) {
            Response::error('Account is inactive', 403);
        }
        
        // Remove password from user payload
        unset($user['password']);
        
        $payload = [
            'iat' => time(),
            'exp' => time() + JWT_EXPIRY,
            'user' => $user
        ];
        
        $token = JWT::encode($payload);
        
        Response::json([
            'token' => $token,
            'user' => $user
        ], 'Login successful');
    }
    
    public function me() {
        $user = AuthMiddleware::authenticate();
        Response::json(['user' => $user]);
    }
    
    public function logout() {
        // Since we are using stateless JWT, we can't truly invalidate it server-side
        // without a database table for blacklisted tokens.
        // For now, the client must discard the token.
        AuthMiddleware::authenticate(); // Ensure they are logged in to log out
        Response::json(null, 'Logout successful');
    }
}
