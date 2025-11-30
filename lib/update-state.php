<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

require 'db.php';

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"]));
}

function updateState($conn) {
    $json = file_get_contents("php://input");
    $data = json_decode($json, true);

    // Validate required fields
    if (empty($data['id']) || empty($data['state_name'])) {
        echo json_encode(["success" => false, "message" => "State ID and name are required"]);
        return;
    }

    $id = intval($data['id']);
    $state_name = trim($data['state_name']);
    $splash_screen = isset($data['splash_screen']) ? trim($data['splash_screen']) : '';

    // Check if state exists
    $stmt = $conn->prepare("SELECT id FROM states WHERE id = ?");
    if (!$stmt) {
        echo json_encode(["success" => false, "message" => "Database error: " . $conn->error]);
        return;
    }
    $stmt->bind_param("i", $id);
    $stmt->execute();
    if ($stmt->get_result()->num_rows == 0) {
        echo json_encode(["success" => false, "message" => "State not found"]);
        return;
    }

    // Update the state
    $stmt = $conn->prepare("UPDATE states SET state_name = ?, splash_screen = ? WHERE id = ?");
    if (!$stmt) {
        echo json_encode(["success" => false, "message" => "Database error: " . $conn->error]);
        return;
    }
    $stmt->bind_param("ssi", $state_name, $splash_screen, $id);

    if ($stmt->execute()) {
        echo json_encode([
            "success" => true,
            "message" => "State updated successfully",
            "state_name" => $state_name,
            "splash_screen" => $splash_screen
        ]);
    } else {
        echo json_encode(["success" => false, "message" => "Error updating state: " . $stmt->error]);
    }
}

updateState($conn);
$conn->close();
?>