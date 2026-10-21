<?php

require_once __DIR__ . '/../models/Lab.php';
require_once __DIR__ . '/../models/Device.php';
require_once __DIR__ . '/../utils/Response.php';
require_once __DIR__ . '/../utils/Validation.php';
require_once __DIR__ . '/../middleware/auth.php';

class LabController {
    private $labModel;

    public function __construct() {
        $this->labModel = new Lab();
    }

    public function index() {
        AuthMiddleware::authenticate();
        $labs = $this->labModel->getAll();
        Response::json($labs);
    }

    public function show($id) {
        AuthMiddleware::authenticate();
        $lab = $this->labModel->findById($id);
        if (!$lab) {
            Response::error('Lab not found', 404);
        }
        Response::json($lab);
    }

    public function store() {
        $user = AuthMiddleware::authenticate();
        if ($user['role'] !== 'admin') {
            Response::error('Unauthorized. Admin privileges required.', 403);
        }

        $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
        $validation = Validation::required(['lab_name', 'building', 'floor', 'room_number'], $input);
        if ($validation !== true) {
            Response::error('Validation failed', 422, $validation);
        }

        $labId = $this->labModel->create($input);
        if ($labId) {
            // Optionally seed fans & lights for this newly created lab
            $fanCount = isset($input['fan_count']) ? (int)$input['fan_count'] : 0;
            $lightCount = isset($input['light_count']) ? (int)$input['light_count'] : 0;
            
            $db = Database::getInstance()->getConnection();
            $stmtDev = $db->prepare("INSERT INTO devices (device_name, device_type, lab_id, status, power_state) VALUES (:name, :type, :lab_id, 'online', 'OFF')");

            for ($f = 1; $f <= $fanCount; $f++) {
                $devName = "Fan $f (" . $input['lab_name'] . ")";
                $type = 'fan';
                $stmtDev->execute([':name' => $devName, ':type' => $type, ':lab_id' => $labId]);
            }

            for ($l = 1; $l <= $lightCount; $l++) {
                $devName = "Light $l (" . $input['lab_name'] . ")";
                $type = 'light';
                $stmtDev->execute([':name' => $devName, ':type' => $type, ':lab_id' => $labId]);
            }

            Response::json(['id' => (int)$labId, 'message' => 'Lab created successfully with devices'], 'Success', 201);
        } else {
            Response::error('Failed to create lab', 500);
        }
    }

    public function destroy($id) {
        $user = AuthMiddleware::authenticate();
        if ($user['role'] !== 'admin') {
            Response::error('Unauthorized. Admin privileges required.', 403);
        }

        if ($this->labModel->delete($id)) {
            Response::json(['message' => 'Lab and associated devices deleted successfully']);
        } else {
            Response::error('Failed to delete lab', 500);
        }
    }
}
