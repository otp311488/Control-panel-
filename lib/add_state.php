<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

require 'db.php';

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"]));
}

function addState($conn) {
    $json = file_get_contents("php://input");
    $data = json_decode($json, true);

    // Validate required fields
    if (empty($data['state_name'])) {
        echo json_encode(["success" => false, "message" => "State name is required"]);
        return;
    }

    $state_name = trim($data['state_name']);
    $splash_screen = isset($data['splash_screen']) ? trim($data['splash_screen']) : '';

    // Check if state already exists
    $stmt = $conn->prepare("SELECT id FROM states WHERE state_name = ?");
    if (!$stmt) {
        echo json_encode(["success" => false, "message" => "Database error: " . $conn->error]);
        return;
    }
    $stmt->bind_param("s", $state_name);
    $stmt->execute();
    if ($stmt->get_result()->num_rows > 0) {
        echo json_encode(["success" => false, "message" => "State already exists"]);
        return;
    }

    // Insert the new state
    $stmt = $conn->prepare("INSERT INTO states (state_name, splash_screen) VALUES (?, ?)");
    if (!$stmt) {
        echo json_encode(["success" => false, "message" => "Database error: " . $conn->error]);
        return;
    }
    $stmt->bind_param("ss", $state_name, $splash_screen);

    if ($stmt->execute()) {
        echo json_encode([
            "success" => true,
            "message" => "State added successfully",
            "state_name" => $state_name,
            "splash_screen" => $splash_screen
        ]);
    } else {
        echo json_encode(["success" => false, "message" => "Error adding state: " . $stmt->error]);
    }
}

addState($conn);
$conn->close();
?>