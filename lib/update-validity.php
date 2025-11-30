<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

// Handle CORS pre-flight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require 'db.php';

if (!$conn) {
    echo json_encode(["success" => false, "message" => "Database connection failed"]);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["success" => false, "message" => "Only POST requests are allowed"]);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
if (!$input || !isset($input['id']) || !isset($input['validity_date'])) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Invalid input: 'id' and 'validity_date' are required"]);
    exit;
}

$id = $input['id'];
$validityDate = $input['validity_date'];

// Validate the date format (MM/DD/YYYY)
if (!preg_match("/^(0[1-9]|1[0-2])\/(0[1-9]|[12][0-9]|3[01])\/\d{4}$/", $validityDate)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Invalid date format. Use MM/DD/YYYY"]);
    exit;
}

try {
    // Convert MM/DD/YYYY to YYYY-MM-DD for MySQL
    $dateParts = explode('/', $validityDate);
    $mysqlDate = "{$dateParts[2]}-{$dateParts[0]}-{$dateParts[1]}";

    $sql = "UPDATE demo_users SET validity_date = ? WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("si", $mysqlDate, $id);
    $stmt->execute();

    if ($stmt->affected_rows > 0) {
        echo json_encode(["success" => true, "message" => "Validity date updated successfully"]);
    } else {
        echo json_encode(["success" => false, "message" => "No demo user found with ID: $id"]);
    }

    $stmt->close();
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Error: " . $e->getMessage()]);
}

$conn->close();
?>