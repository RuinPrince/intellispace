<?php

require_once __DIR__ . '/../utils/Response.php';

class Router {
    private $routes = [];

    public function get($path, $controllerAction) {
        $this->addRoute('GET', $path, $controllerAction);
    }

    public function post($path, $controllerAction) {
        $this->addRoute('POST', $path, $controllerAction);
    }

    public function put($path, $controllerAction) {
        $this->addRoute('PUT', $path, $controllerAction);
    }

    public function patch($path, $controllerAction) {
        $this->addRoute('PATCH', $path, $controllerAction);
    }

    public function delete($path, $controllerAction) {
        $this->addRoute('DELETE', $path, $controllerAction);
    }

    private function addRoute($method, $path, $controllerAction) {
        // Convert route params like {id} to regex named capture groups
        $pattern = preg_replace('/\{([a-zA-Z0-9_]+)\}/', '(?P<\1>[a-zA-Z0-9_-]+)', $path);
        $pattern = '#^' . $pattern . '$#';
        
        $this->routes[] = [
            'method' => $method,
            'pattern' => $pattern,
            'action' => $controllerAction
        ];
    }

    public function dispatch($method, $uri) {
        // Remove API_BASE_PATH if present
        $basePath = defined('API_BASE_PATH') ? API_BASE_PATH : '';
        if ($basePath && strpos($uri, $basePath) === 0) {
            $uri = substr($uri, strlen($basePath));
        }
        
        // Remove query string
        if (($pos = strpos($uri, '?')) !== false) {
            $uri = substr($uri, 0, $pos);
        }
        
        // Ensure trailing slash is handled consistently
        if ($uri !== '/' && substr($uri, -1) === '/') {
            $uri = substr($uri, 0, -1);
        }
        if ($uri === '') {
            $uri = '/';
        }

        foreach ($this->routes as $route) {
            if ($route['method'] === $method && preg_match($route['pattern'], $uri, $matches)) {
                $params = [];
                foreach ($matches as $key => $value) {
                    if (is_string($key)) {
                        $params[$key] = $value;
                    }
                }
                
                list($controllerClass, $methodName) = explode('@', $route['action']);
                
                // Include controller file
                require_once __DIR__ . '/../controllers/' . $controllerClass . '.php';
                
                $controller = new $controllerClass();
                call_user_func_array([$controller, $methodName], $params);
                return;
            }
        }
        
        Response::error('Not Found: ' . $method . ' ' . $uri, 404);
    }
}

$router = new Router();

// ==========================================================
// ROUTE DEFINITIONS (Modified Specification)
// ==========================================================

// Health & DB Connection Check
$router->get('/health', 'HealthController@check');

// Authentication
$router->post('/auth/login', 'AuthController@login');
$router->get('/auth/me', 'AuthController@me');
$router->post('/auth/logout', 'AuthController@logout');

// Dashboard Overview
$router->get('/dashboard', 'DashboardController@index');

// Users & Teacher Management
$router->get('/users', 'UserController@index');
$router->get('/users/{id}', 'UserController@show');
$router->post('/users', 'UserController@store');
$router->put('/users/{id}', 'UserController@update');
$router->patch('/users/{id}', 'UserController@update');
$router->delete('/users/{id}', 'UserController@destroy');

// Labs Management
$router->get('/labs', 'LabController@index');
$router->get('/labs/{id}', 'LabController@show');
$router->post('/labs', 'LabController@store');
$router->delete('/labs/{id}', 'LabController@destroy');

// Devices (Fan & Light Control)
$router->get('/devices', 'DeviceController@index');
$router->get('/devices/{id}', 'DeviceController@show');
$router->post('/devices/{id}/control', 'DeviceController@control');

// Attendance Management
$router->get('/attendance/summary', 'AttendanceController@summary');
$router->get('/attendance/today', 'AttendanceController@today');
$router->get('/attendance/date/{date}', 'AttendanceController@byDate');
$router->get('/attendance/student/{id}', 'AttendanceController@byStudent');
$router->post('/attendance', 'AttendanceController@store');

// Notifications (Filtered: Device & Attendance)
$router->get('/notifications', 'NotificationController@index');
$router->get('/notifications/unread', 'NotificationController@unread');
$router->put('/notifications/{id}/read', 'NotificationController@markRead');
$router->put('/notifications/read-all', 'NotificationController@markAllRead');
$router->delete('/notifications/{id}', 'NotificationController@destroy');

return $router;
