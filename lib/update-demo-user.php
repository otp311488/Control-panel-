<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

// Handle CORS preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require 'db.php';

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"]));
}

function updateDemoUser($conn) {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        echo json_encode(["success" => false, "message" => "Only POST requests are allowed"]);
        return;
    }

    $json = file_get_contents("php://input");
    $data = json_decode($json, true);

    if (empty($data['id']) || empty($data['mobile_number']) || empty($data['state_id']) || empty($data['validity_date'])) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "ID, mobile number, state ID, and validity date are required"]);
        return;
    }

    $id = intval($data['id']);
    $mobile_number = trim($data['mobile_number']);
    $state_id = intval($data['state_id']);
    $validity_date = $data['validity_date'];

    // Validation logic
    if ($id <= 0) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Invalid user ID"]);
        return;
    }
    if (!preg_match('/^\d{10}$/', $mobile_number)) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Mobile number must be exactly 10 digits"]);
        return;
    }
    if ($state_id <= 0) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Invalid state ID"]);
        return;
    }
    if (!preg_match('/^\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}$/', $validity_date)) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Invalid validity date format. Use YYYY-MM-DD HH:MM:SS"]);
        return;
    }

    try {
        $currentDate = new DateTime();
        $validityDate = DateTime::createFromFormat('Y-m-d H:i:s', $validity_date);
        if (!$validityDate || $validityDate->format('Y-m-d H:i:s') !== $validity_date) {
            throw new Exception("Invalid date");
        }
        if ($validityDate < $currentDate) {
            throw new Exception("Validity date must be in the future");
        }
        $interval = $currentDate->diff($validityDate);
        $validity = $interval->days;
    } catch (Exception $e) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Invalid validity date: " . $e->getMessage()]);
        return;
    }

    $stmt = $conn->prepare("SELECT * FROM demo_users WHERE id = ?");
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        $stmt->close();
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "User not found"]);
        return;
    }

    $stmt = $conn->prepare("SELECT * FROM demo_users WHERE mobile_number = ? AND id != ?");
    $stmt->bind_param("si", $mobile_number, $id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $stmt->close();
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Mobile number already in use by another user"]);
        return;
    }

    $stmt = $conn->prepare("UPDATE demo_users SET mobile_number = ?, state_id = ?, validity = ?, created_at = ? WHERE id = ?");
    $stmt->bind_param("siisi", $mobile_number, $state_id, $validity, $validity_date, $id);

    if ($stmt->execute()) {
        $stmt->close();
        echo json_encode([
            "success" => true,
            "message" => "Demo user updated successfully",
            "validity" => $validity,
            "validity_date" => $validity_date,
        ]);
    } else {
        $error = $stmt->error;
        $stmt->close();
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Error updating demo user: " . $error]);
    }
}

updateDemoUser($conn);
$conn->close();
?>