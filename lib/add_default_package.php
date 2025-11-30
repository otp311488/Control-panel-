<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

require 'db.php';

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"]));
}

function addDefaultPackage($conn) {
    $json = file_get_contents("php://input");
    $data = json_decode($json, true);

    if (empty($data['package_name']) || empty($data['state_id']) || empty($data['file_name'])) {
        echo json_encode(["success" => false, "message" => "All fields are required"]);
        return;
    }

    $package_name = trim($data['package_name']);
    $state_id = intval($data['state_id']);
    $file_name = trim($data['file_name']);

    $stmt = $conn->prepare("SELECT * FROM default_packages WHERE package_name = ? AND state_id = ?");
    $stmt->bind_param("si", $package_name, $state_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        echo json_encode(["success" => false, "message" => "Package name must be unique for the selected state"]);
        return;
    }

    $stmt = $conn->prepare("INSERT INTO default_packages (package_name, state_id, file_name) VALUES (?, ?, ?)");
    $stmt->bind_param("sis", $package_name, $state_id, $file_name);

    if ($stmt->execute()) {
        echo json_encode(["success" => true, "message" => "Default package added successfully"]);
    } else {
        echo json_encode(["success" => false, "message" => "Error adding package: " . $stmt->error]);
    }
}

addDefaultPackage($conn);
?>