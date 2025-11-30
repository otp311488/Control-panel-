<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Accept, User-Agent");

// Handle OPTIONS requests (CORS preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    header("HTTP/1.1 204 No Content");
    exit;
}

function uploadFile() {
    if (!isset($_FILES['file'])) {
        error_log("No file uploaded in request");
        echo json_encode(["success" => false, "message" => "No file uploaded"]);
        return;
    }
    if ($_FILES['file']['error'] !== UPLOAD_ERR_OK) {
        error_log("File upload error: " . $_FILES['file']['error']);
        echo json_encode(["success" => false, "message" => "File upload error: " . $_FILES['file']['error']]);
        return;
    }

    // Use the correct upload directory as per logs
    $uploadDir = '/home/mgdngzpm/sms/uploads/';
    error_log("Upload directory set to: $uploadDir");

    if (!file_exists($uploadDir)) {
        if (mkdir($uploadDir, 0755, true)) {
            error_log("Created upload directory: $uploadDir");
        } else {
            error_log("Error: Failed to create upload directory: $uploadDir");
            echo json_encode(["success" => false, "message" => "Failed to create uploads directory"]);
            return;
        }
    }

    $baseName = basename($_FILES['file']['name']);
    $fileName = uniqid() . "_" . $baseName;
    $filePath = $uploadDir . $fileName;

    if (move_uploaded_file($_FILES['file']['tmp_name'], $filePath)) {
        error_log("File uploaded successfully: $filePath");
        // Ensure the file is readable
        chmod($filePath, 0644);
        echo json_encode([
            "success" => true,
            "file_name" => $fileName,
            "message" => "File uploaded successfully",
            "url" => "https://sms.mydreamplaytv.com/uploads/$fileName" // Adjust this URL based on web accessibility
        ]);
    } else {
        error_log("Error: Failed to move uploaded file to: $filePath");
        echo json_encode(["success" => false, "message" => "Error moving uploaded file"]);
    }
}

function serveFile() {
    if (!isset($_GET['file_name'])) {
        error_log("No file name provided in GET request");
        header("HTTP/1.1 400 Bad Request");
        header("Content-Type: application/json");
        echo json_encode(["success" => false, "message" => "No file name provided"]);
        return;
    }

    $fileName = basename($_GET['file_name']); // Prevent directory traversal

    // Define all possible upload directories
    $uploadDirs = [
        '/home/mgdngzpm/sms/uploads/',
        $_SERVER['DOCUMENT_ROOT'] . '/uploads/',
        '/home/mgdngzpm/public_html/uploads/'
    ];

    $filePath = null;
    foreach ($uploadDirs as $dir) {
        $potentialPath = $dir . $fileName;
        error_log("Checking for file in: $potentialPath");
        if (file_exists($potentialPath)) {
            $filePath = $potentialPath;
            error_log("File found in: $filePath");
            break;
        }
    }

    if (!$filePath) {
        error_log("File not found in any directory: $fileName");
        header("HTTP/1.1 404 Not Found");
        header("Content-Type: application/json");
        echo json_encode(["success" => false, "message" => "File not found"]);
        return;
    }

    // Determine the MIME type based on file extension
    $extension = strtolower(pathinfo($filePath, PATHINFO_EXTENSION));
    $mimeTypes = [
        'png' => 'image/png',
        'jpg' => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'gif' => 'image/gif',
        'txt' => 'text/plain',
    ];
    $contentType = isset($mimeTypes[$extension]) ? $mimeTypes[$extension] : 'application/octet-stream';

    // Serve the file directly
    header("Content-Type: $contentType");
    header("Content-Length: " . filesize($filePath));
    header("Content-Disposition: inline; filename=\"" . basename($fileName) . "\"");
    readfile($filePath);
    error_log("File served successfully: $filePath");
    exit;
}

// Handle the request based on the method
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    header("Content-Type: application/json");
    uploadFile();
} elseif ($_SERVER['REQUEST_METHOD'] === 'GET') {
    serveFile();
} else {
    header("HTTP/1.1 405 Method Not Allowed");
    header("Content-Type: application/json");
    echo json_encode(["success" => false, "message" => "Method not allowed"]);
}
?>