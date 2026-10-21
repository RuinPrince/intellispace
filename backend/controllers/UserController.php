<?php

require_once __DIR__ . '/../models/User.php';
require_once __DIR__ . '/../utils/Response.php';
require_once __DIR__ . '/../utils/Validation.php';
require_once __DIR__ . '/../middleware/auth.php';

class UserController {
    private $userModel;

    public function __construct() {
        $this->userModel = new User();
    }

    public function index() {
        AuthMiddleware::requireRole('admin');
        $users = $this->userModel->getAll();
        Response::json($users);
    }

    public function show($id) {
        $currentUser = AuthMiddleware::authenticate();
        
        // Users can view themselves, admins can view anyone
        if ($currentUser['id'] != $id && $currentUser['role'] !== 'admin') {
            Response::error('Forbidden', 403);
        }
        
        $user = $this->userModel->findById($id);
        if (!$user) {
            Response::error('User not found', 404);
        }
        Response::json($user);
    }

    public function store() {
        AuthMiddleware::requireRole('admin');

        $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
        $validation = Validation::required(['name', 'email', 'password'], $input);
        if ($validation !== true) {
            Response::error('Validation failed', 422, $validation);
        }

        // Check if Teacher ID/Email already exists
        if ($this->userModel->findByEmail($input['email'])) {
            Response::error('User ID / Email already exists', 409);
        }

        $userId = $this->userModel->create($input);
        if ($userId) {
            $created = $this->userModel->findById($userId);
            Response::json($created, 'Teacher account created successfully', 201);
        } else {
            Response::error('Failed to create teacher account', 500);
        }
    }

    public function update($id) {
        $currentUser = AuthMiddleware::authenticate();
        
        // Users can update themselves, admins can update anyone
        if ($currentUser['id'] != $id && $currentUser['role'] !== 'admin') {
            Response::error('Forbidden', 403);
        }
        
        $user = $this->userModel->findById($id);
        if (!$user) {
            Response::error('User not found', 404);
        }
        
        $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
        $data = [];
        
        if (isset($input['name']) && trim($input['name']) !== '') {
            $data['name'] = trim($input['name']);
        }
        // Allow modifying Teacher ID (Email) if admin
        if (isset($input['email']) && trim($input['email']) !== '') {
            if ($currentUser['role'] === 'admin') {
                $data['email'] = trim($input['email']);
            }
        }
        // Allow modifying role if admin
        if (isset($input['role']) && trim($input['role']) !== '') {
            if ($currentUser['role'] === 'admin') {
                $data['role'] = trim($input['role']);
            }
        }
        if (isset($input['department'])) {
            $data['department'] = trim($input['department']);
        }
        if (isset($input['profile_image'])) {
            $data['profile_image'] = trim($input['profile_image']);
        }
        if (!empty($input['password'])) {
            $data['password'] = $input['password'];
        }
        
        if (empty($data)) {
            Response::error('No valid fields provided for update', 422);
        }
        
        $success = $this->userModel->update($id, $data);
        if ($success) {
            $updatedUser = $this->userModel->findById($id);
            Response::json($updatedUser, 'User updated successfully');
        } else {
            Response::error('Failed to update user', 500);
        }
    }

    public function destroy($id) {
        AuthMiddleware::requireRole('admin');
        
        if ($this->userModel->delete($id)) {
            Response::json(['message' => 'User account deleted successfully']);
        } else {
            Response::error('Failed to delete user account', 500);
        }
    }
}
