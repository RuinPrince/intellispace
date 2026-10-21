<?php

// Database Configuration
define('DB_HOST', 'localhost');
define('DB_PORT', '3306');
define('DB_NAME', 'intellispace');
define('DB_USER', 'root');
define('DB_PASS', '');

// Application Configuration
define('APP_NAME', 'IntelliSpace API');
define('APP_VERSION', '1.0.0');
define('API_BASE_PATH', '/intellispace_backend/public/api');

// JWT Configuration
// Generate a secure random key in production. For development, we use this static key.
define('JWT_SECRET', 'super_secret_intellispace_jwt_key_2026!');
define('JWT_EXPIRY', 86400); // 24 hours

// CORS Configuration
define('CORS_ALLOWED_ORIGINS', '*'); // Allow all for development. Restrict in production.
