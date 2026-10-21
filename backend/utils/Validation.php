<?php

class Validation {
    public static function required($fields, $data) {
        $errors = [];
        foreach ($fields as $field) {
            if (!isset($data[$field]) || trim($data[$field]) === '') {
                $errors[$field] = ucfirst(str_replace('_', ' ', $field)) . ' is required.';
            }
        }
        return empty($errors) ? true : $errors;
    }

    public static function email($email) {
        return filter_var($email, FILTER_VALIDATE_EMAIL) !== false;
    }

    public static function in($value, $allowedValues) {
        return in_array($value, $allowedValues, true);
    }
}
