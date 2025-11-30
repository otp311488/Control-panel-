<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

require 'db.php';

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"]));
}

function updateScrollingMessage($conn) {
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        exit; // Handle CORS preflight
    }

    $json = file_get_contents("php://input");
    $data = json_decode($json, true);

    // Check for required fields
    if (empty($data['id']) || empty($data['scrolling_name']) || empty($data['script']) || empty($data['time_schedule']) || 
        empty($data['duration']) || empty($data['start_date']) || empty($data['end_date'])) {
        echo json_encode(["success" => false, "message" => "ID, scrolling name, script, time schedule, duration, start date, and end date are required"]);
        return;
    }

    $id = trim($data['id']);
    $scrolling_name = trim($data['scrolling_name']);
    $script = trim($data['script']);
    $time_schedule = trim($data['time_schedule']);
    $duration = (int)$data['duration']; // Ensure duration is an integer
    $start_date = trim($data['start_date']);
    $end_date = trim($data['end_date']);

    // Validate date format (YYYY-MM-DD)
    if (!preg_match("/^\d{4}-\d{2}-\d{2}$/", $start_date) || !preg_match("/^\d{4}-\d{2}-\d{2}$/", $end_date)) {
        echo json_encode(["success" => false, "message" => "Invalid date format. Use YYYY-MM-DD"]);
        return;
    }

    // Prepare and execute the update statement
    $stmt = $conn->prepare("UPDATE scrolling_messages SET scrolling_name = ?, script = ?, time_schedule = ?, duration = ?, start_date = ?, end_date = ? WHERE id = ?");
    $stmt->bind_param("sssissi", $scrolling_name, $script, $time_schedule, $duration, $start_date, $end_date, $id);

    if ($stmt->execute()) {
        if ($stmt->affected_rows > 0) {
            echo json_encode(["success" => true, "message" => "Scrolling message updated successfully"]);
        } else {
            echo json_encode(["success" => false, "message" => "No scrolling message found with the given ID"]);
        }
    } else {
        echo json_encode(["success" => false, "message" => "Error updating scrolling message: " . $stmt->error]);
    }

    $stmt->close();
}

updateScrollingMessage($conn);
$conn->close();
?>