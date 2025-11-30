<?php
// Fetch file content from local filesystem by base name
function fetchDemoFileContent($file_name) {
    $base_dir = $_SERVER['DOCUMENT_ROOT'] . '/uploads/';
    error_log("Base directory set to: $base_dir");

    // Check if the directory exists, create it if it doesn't
    if (!file_exists($base_dir)) {
        if (mkdir($base_dir, 0755, true)) {
            error_log("Created directory: $base_dir");
        } else {
            error_log("Error: Failed to create directory: $base_dir");
            return false;
        }
    }

    // Handle the file name, whether it's a URL or a direct file name
    $parsed_url = filter_var($file_name, FILTER_VALIDATE_URL) ? parse_url($file_name, PHP_URL_PATH) : $file_name;
    $full_file_name = basename($parsed_url);
    // Use 16-character prefix, consistent with fetchFileContent from first API
    $base_name = preg_replace('/^[0-9a-f]{16}[-_]?/', '', $full_file_name);
    error_log("Extracted base name: $base_name from file_name: $file_name");

    // Look for files matching the pattern
    $files = glob($base_dir . "*_" . $base_name);
    // Fallback to full file name if prefix-based search fails
    if (empty($files)) {
        $files = glob($base_dir . $full_file_name);
    }

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
        error_log("Error: No file found in $base_dir with base name: $base_name or full name: $full_file_name");
        return false;
    }
}
?>