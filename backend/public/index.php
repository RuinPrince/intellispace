<?php

// Enable error reporting for development
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// Load configuration
require_once __DIR__ . '/../config/config.php';

// Load CORS middleware first to handle preflight requests
require_once __DIR__ . '/../middleware/cors.php';

// Load the router and routes
$router = require_once __DIR__ . '/../routes/api.php';

// Get HTTP method and URI
$method = $_SERVER['REQUEST_METHOD'];
$uri = $_SERVER['REQUEST_URI'];

// Read raw JSON body if present and add it to $_POST
if ($method === 'POST' || $method === 'PUT') {
    $json = file_get_contents('php://input');
    if (!empty($json)) {
        $data = json_decode($json, true);
        if (json_last_error() === JSON_ERROR_NONE) {
            $_POST = array_merge($_POST, $data);
        }
    }
}

// Dispatch the request
try {
    $router->dispatch($method, $uri);
} catch (Exception $e) {
    // Global exception handler
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'message' => 'Internal Server Error',
        'error' => $e->getMessage() // Remove this in production
    ]);
}
