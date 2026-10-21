<?php

require_once __DIR__ . '/../models/Device.php';
require_once __DIR__ . '/../utils/Response.php';
require_once __DIR__ . '/../utils/Validation.php';
require_once __DIR__ . '/../middleware/auth.php';

class DeviceController {
    private $deviceModel;

    public function __construct() {
        $this->deviceModel = new Device();
    }

    public function index() {
        AuthMiddleware::authenticate();
        $devices = $this->deviceModel->getAll();
        Response::json($devices);
    }

    public function show($id) {
        AuthMiddleware::authenticate();
        $device = $this->deviceModel->findById($id);
        
        if (!$device) {
            Response::error('Device not found', 404);
        }
        
        Response::json($device);
    }

    public function control($id) {
        $user = AuthMiddleware::authenticate();
        
        $validation = Validation::required(['power_state'], $_POST);
        if ($validation !== true) {
            Response::error('Validation failed', 422, $validation);
        }
        
        $state = strtoupper($_POST['power_state']);
        if (!Validation::in($state, ['ON', 'OFF'])) {
            Response::error('Invalid power_state. Must be ON or OFF.', 422);
        }
        
        $device = $this->deviceModel->findById($id);
        if (!$device) {
            Response::error('Device not found', 404);
        }
        
        // Store old state for logging
        $oldState = $device['power_state'];
        
        $success = $this->deviceModel->updatePowerState($id, $state);
        
        if ($success) {
            // Log the action for audit trail
            $this->deviceModel->logAction(
                $id, 
                'power_state_change', 
                $user['id'], 
                $oldState, 
                $state
            );
            
            // In a real app, we would send a signal to the ESP32/IoT broker here (e.g., MQTT)
            // The architecture supports this by keeping the device control logic isolated.
            
            Response::json([
                'device_id' => (int)$id,
                'device_name' => $device['device_name'],
                'power_state' => $state,
                'previous_state' => $oldState,
                'controlled_by' => $user['id']
            ], 'Device state updated successfully');
        } else {
            Response::error('Failed to update device state', 500);
        }
    }
}
