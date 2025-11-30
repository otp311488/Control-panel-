<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

require 'db.php';

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"]));
}

function updateDefaultPackage($conn) {
    $json = file_get_contents("php://input");
    $data = json_decode($json, true);

    // Validate required fields
    if (empty($data['id']) || empty($data['package_name']) || empty($data['state_id']) || empty($data['file_name'])) {
        echo json_encode(["success" => false, "message" => "All fields (id, package_name, state_id, file_name) are required"]);
        return;
    }

    $id = intval($data['id']);
    $package_name = trim($data['package_name']);
    $state_id = intval($data['state_id']);
    $file_name = trim($data['file_name']);

    // Check if the package exists
    $stmt = $conn->prepare("SELECT * FROM default_packages WHERE id = ?");
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        echo json_encode(["success" => false, "message" => "Package not found"]);
        return;
    }

    // Check for uniqueness (excluding the current record)
    $stmt = $conn->prepare("SELECT * FROM default_packages WHERE package_name = ? AND state_id = ? AND id != ?");
    $stmt->bind_param("sii", $package_name, $state_id, $id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        echo json_encode(["success" => false, "message" => "Package name must be unique for the selected state"]);
        return;
    }

    // Update the package
    $stmt = $conn->prepare("UPDATE default_packages SET package_name = ?, state_id = ?, file_name = ? WHERE id = ?");
    $stmt->bind_param("sisi", $package_name, $state_id, $file_name, $id);

    if ($stmt->execute()) {
        echo json_encode(["success" => true, "message" => "Default package updated successfully"]);
    } else {
        echo json_encode(["success" => false, "message" => "Error updating package: " . $stmt->error]);
    }
}

updateDefaultPackage($conn);
?>