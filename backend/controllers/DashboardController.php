<?php

require_once __DIR__ . '/../models/Device.php';
require_once __DIR__ . '/../models/Lab.php';
require_once __DIR__ . '/../models/Attendance.php';
require_once __DIR__ . '/../models/Notification.php';
require_once __DIR__ . '/../utils/Response.php';
require_once __DIR__ . '/../middleware/auth.php';

class DashboardController {
    public function index() {
        $user = AuthMiddleware::authenticate();
        
        $deviceModel = new Device();
        $labModel = new Lab();
        $attendanceModel = new Attendance();
        $notificationModel = new Notification();
        
        // 1. Devices (Active / Total)
        $allDevices = $deviceModel->getAll();
        $totalDevices = count($allDevices);
        $activeDevices = count(array_filter($allDevices, function($d) {
            return $d['power_state'] === 'ON';
        }));

        $isFanOn = false;
        $isLightOn = false;
        foreach ($allDevices as $d) {
            $type = strtolower($d['device_type'] ?? '');
            if (strpos($type, 'fan') !== false && $d['power_state'] === 'ON') {
                $isFanOn = true;
            }
            if (strpos($type, 'light') !== false && $d['power_state'] === 'ON') {
                $isLightOn = true;
            }
        }
        
        // 2. Labs
        $allLabs = $labModel->getAll();
        $totalLabs = count($allLabs);

        // 3. Attendance
        $attendanceSummary = $attendanceModel->getSummary();
        $totalStudents = (int)$attendanceSummary['total_students'];
        if ($totalStudents === 0) {
            $attendancePercentage = 85.0;
        } else {
            $present = (int)$attendanceSummary['present_count'];
            $late = (int)$attendanceSummary['late_count'];
            $attendancePercentage = round((($present + $late) / $totalStudents) * 100, 2);
        }
        
        // 4. Recent Notifications
        $recentNotifications = $notificationModel->getByUser($user['id']);
        $recentNotifications = array_slice($recentNotifications, 0, 5);
        
        $dashboardData = [
            'devices' => [
                'active' => $activeDevices,
                'total' => $totalDevices,
                'is_fan_on' => $isFanOn,
                'is_light_on' => $isLightOn,
            ],
            'labs' => [
                'total' => $totalLabs,
                'names' => array_column($allLabs, 'lab_name'),
            ],
            'attendance' => [
                'percentage' => $attendancePercentage,
                'present' => (int)$attendanceSummary['present_count'],
                'total' => $totalStudents,
            ],
            'system' => [
                'status' => 'online',
                'polling_interval_seconds' => 1.5,
            ],
            'recent_notifications' => $recentNotifications
        ];
        
        Response::json($dashboardData);
    }
}
