<?php

require_once __DIR__ . '/../models/Notification.php';
require_once __DIR__ . '/../utils/Response.php';
require_once __DIR__ . '/../middleware/auth.php';

class NotificationController {
    private $notificationModel;

    public function __construct() {
        $this->notificationModel = new Notification();
    }

    public function index() {
        $user = AuthMiddleware::authenticate();
        $notifications = $this->notificationModel->getByUser($user['id']);
        Response::json($notifications);
    }

    public function unread() {
        $user = AuthMiddleware::authenticate();
        $notifications = $this->notificationModel->getUnread($user['id']);
        Response::json($notifications);
    }

    public function markRead($id) {
        $user = AuthMiddleware::authenticate();
        $success = $this->notificationModel->markRead($id, $user['id']);
        
        if ($success) {
            Response::json(['id' => $id], 'Notification marked as read');
        } else {
            Response::error('Failed to mark notification or not found', 404);
        }
    }

    public function markAllRead() {
        $user = AuthMiddleware::authenticate();
        $success = $this->notificationModel->markAllRead($user['id']);
        
        if ($success) {
            Response::json(null, 'All notifications marked as read');
        } else {
            Response::error('Failed to update notifications', 500);
        }
    }

    public function destroy($id) {
        $user = AuthMiddleware::authenticate();
        $success = $this->notificationModel->delete($id, $user['id']);
        
        if ($success) {
            Response::json(['id' => $id], 'Notification deleted');
        } else {
            Response::error('Failed to delete notification or not found', 404);
        }
    }
}
