<?php

require_once __DIR__ . '/../config/config.php';

// Allow from any origin if CORS_ALLOWED_ORIGINS is '*'
if (CORS_ALLOWED_ORIGINS === '*') {
    header("Access-Control-Allow-Origin: *");
} else if (isset($_SERVER['HTTP_ORIGIN']) && in_array($_SERVER['HTTP_ORIGIN'], explode(',', CORS_ALLOWED_ORIGINS))) {
    header("Access-Control-Allow-Origin: {$_SERVER['HTTP_ORIGIN']}");
}

header("Access-Control-Allow-Credentials: true");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}
