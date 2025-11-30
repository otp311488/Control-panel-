<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

require 'db.php'; // Your database connection file

if (!$conn) {
    echo json_encode(["success" => false, "message" => "Database connection failed"]);
    exit;
}

try {
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        // Debug: Log raw POST data
        file_put_contents('debug.log', "POST data: " . print_r($_POST, true) . "\n", FILE_APPEND);
        file_put_contents('debug.log', "FILES data: " . print_r($_FILES, true) . "\n", FILE_APPEND);

        if (!isset($_POST['data'])) {
            // Fallback: Try reading raw input (unlikely needed for multipart)
            $input = file_get_contents('php://input');
            file_put_contents('debug.log', "Raw input: $input\n", FILE_APPEND);
            echo json_encode(["success" => false, "message" => "No JSON data provided in POST['data']"]);
            exit;
        }

        $input = $_POST['data'];
        $data = json_decode($input, true);

        if (json_last_error() !== JSON_ERROR_NONE) {
            file_put_contents('debug.log', "JSON decode error: " . json_last_error_msg() . "\n", FILE_APPEND);
            echo json_encode([
                "success" => false,
                "message" => "Invalid JSON: " . json_last_error_msg(),
                "raw_input" => $input
            ]);
            exit;
        }

        if (!isset($data['id']) || !isset($data['package_name']) || !isset($data['partner_id']) || !isset($data['partner_code'])) {
            echo json_encode(["success" => false, "message" => "Missing required fields"]);
            exit;
        }

        $id = $data['id'];
        $package_name = $data['package_name'];
        $partner_id = $data['partner_id'];
        $partner_code = $data['partner_code'];

        $file_name = null;
        if (isset($_FILES['file']) && $_FILES['file']['error'] === UPLOAD_ERR_OK) {
            // Allow all file types or specify desired extensions
            $allowedExtensions = ['txt', 'm3u', 'csv', 'xlsx', 'xls', 'jpg', 'jpeg', 'png', 'pdf'];
            $maxFileSize = 5 * 1024 * 1024; // 5MB

            $fileExtension = strtolower(pathinfo($_FILES['file']['name'], PATHINFO_EXTENSION));
            if (!in_array($fileExtension, $allowedExtensions)) {
                echo json_encode(["success" => false, "message" => "Invalid file type. Allowed types: " . implode(', ', $allowedExtensions)]);
                exit;
            }

            if ($_FILES['file']['size'] > $maxFileSize) {
                echo json_encode(["success" => false, "message" => "File size exceeds the maximum limit of 5MB."]);
                exit;
            }

            $uploadDir = 'Uploads/';
            if (!is_dir($uploadDir)) {
                mkdir($uploadDir, 0777, true);
            }

            // Generate a unique file name to avoid overwrites
            $uniquePrefix = uniqid() . '_';
            $file_name = $uniquePrefix . preg_replace('/[^a-zA-Z0-9_\-\.]/', '_', basename($_FILES['file']['name']));
            $uploadPath = $uploadDir . $file_name;

            if (!move_uploaded_file($_FILES['file']['tmp_name'], $uploadPath)) {
                echo json_encode(["success" => false, "message" => "Failed to upload file"]);
                exit;
            }
        } else {
            $file_name = isset($data['file_name']) ? $data['file_name'] : null;
        }

        $sql = "UPDATE partner_packages SET package_name = ?, partner_id = ?, partner_code = ?";
        $params = [$package_name, $partner_id, $partner_code];
        $types = "sss";

        if ($file_name !== null) {
            $sql .= ", file_name = ?";
            $params[] = $file_name;
            $types .= "s";
        }
        $sql .= " WHERE id = ?";
        $params[] = $id;
        $types .= "s";

        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            file_put_contents('debug.log', "Prepare failed: " . $conn->error . "\n", FILE_APPEND);
            echo json_encode(["success" => false, "message" => "Prepare failed: " . $conn->error]);
            exit;
        }

        $stmt->bind_param($types, ...$params);

        if ($stmt->execute()) {
            echo json_encode(["success" => true, "message" => "Partner package updated successfully"]);
        } else {
            file_put_contents('debug.log', "Execute failed: " . $stmt->error . "\n", FILE_APPEND);
            echo json_encode(["success" => false, "message" => "Failed to update partner package: " . $stmt->error]);
        }

        $stmt->close();
    } else {
        echo json_encode(["success" => false, "message" => "Invalid request method"]);
    }

} catch (Exception $e) {
    file_put_contents('debug.log', "Exception: " . $e->getMessage() . "\n", FILE_APPEND);
    echo json_encode(["success" => false, "message" => "Error: " . $e->getMessage()]);
}

$conn->close();
?>