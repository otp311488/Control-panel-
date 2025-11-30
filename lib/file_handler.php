<?php
// Convert filename to full URL
function getFileUrl($fileName) {
    if (empty($fileName)) {
        return "";
    }
    return "https://sms.mydreamplaytv.com/upload-file.php?file_name=" . urlencode(basename($fileName));
}

// Fetch file content from local filesystem by base name
function fetchFileContent($file_name) {
    $base_dir = $_SERVER['DOCUMENT_ROOT'] . '/uploads/';
    error_log("Base directory set to: $base_dir");

    if (!file_exists($base_dir)) {
        if (mkdir($base_dir, 0755, true)) {
            error_log("Created directory: $base_dir");
        } else {
            error_log("Error: Failed to create directory: $base_dir");
            return false;
        }
    }

    $parsed_url = filter_var($file_name, FILTER_VALIDATE_URL) ? parse_url($file_name, PHP_URL_PATH) : $file_name;
    $full_file_name = basename($parsed_url);
    $base_name = preg_replace('/^[0-9a-f]{13}_/', '', $full_file_name);
    error_log("Extracted base name: $base_name from file_name: $file_name");

    $files = glob($base_dir . "*_" . $base_name);
    if (!empty($files)) {
        $full_path = $files[0];
        error_log("Found matching file: $full_path");
        $content = file_get_contents($full_path);
        if ($content !== false) {
            error_log("Successfully fetched content from: $full_path - Content length: " . strlen($content));
            return $content;
        } else {
            error_log("Error: Failed to read file content from: $full_path - Check permissions");
            return false;
        }
    } else {
        error_log("Error: No file found in $base_dir with base name: $base_name");
        return false;
    }
}
?>