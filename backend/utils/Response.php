<?php

class Response {
    public static function json($data, $message = 'Success', $code = 200) {
        http_response_code($code);
        header('Content-Type: application/json');
        
        $response = [
            'success' => true,
            'message' => $message,
            'data' => $data
        ];
        
        echo json_encode($response);
        exit();
    }

    public static function error($message = 'An error occurred', $code = 400, $errors = null) {
        http_response_code($code);
        header('Content-Type: application/json');
        
        $response = [
            'success' => false,
            'message' => $message
        ];
        
        if ($errors !== null) {
            $response['errors'] = $errors;
        }
        
        echo json_encode($response);
        exit();
    }
}
