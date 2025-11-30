<?php
ob_start();
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

require 'db.php';

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"]));
}

function addDemoUser($conn) {
    $json = file_get_contents("php://input");
    $data = json_decode($json, true);

    // Validate required fields
    if (empty($data['mobile_number']) || empty($data['state_id'])) {
        echo json_encode(["success" => false, "message" => "Mobile number and state ID are required"]);
        return;
    }

    $mobile_number = trim($data['mobile_number']);
    $state_id = intval($data['state_id']);

    // Validate mobile number format
    if (!preg_match('/^\d{10}$/', $mobile_number)) {
        echo json_encode(["success" => false, "message" => "Mobile number must be 10 digits"]);
        return;
    }

    // Check if the user already exists
    $stmt = $conn->prepare("SELECT * FROM demo_users WHERE mobile_number = ?");
    if (!$stmt) {
        echo json_encode(["success" => false, "message" => "Database error: " . $conn->error]);
        return;
    }
    $stmt->bind_param("s", $mobile_number);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        echo json_encode(["success" => false, "message" => "User already exists"]);
        return;
    }

    // Fetch the default package for the given state
    $stmt = $conn->prepare("SELECT id, package_name, file_name, validity FROM default_packages WHERE state_id = ? LIMIT 1");
    if (!$stmt) {
        echo json_encode(["success" => false, "message" => "Database error: " . $conn->error]);
        return;
    }
    $stmt->bind_param("i", $state_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $package = $result->fetch_assoc();

    if (!$package) {
        echo json_encode(["success" => false, "message" => "No package found for the given state ID"]);
        return;
    }

    $default_pack_id = $package["id"];
    $default_pack = $package["package_name"] ?? "Default Pack";
    $default_validity = $package["validity"] ?? 30;
    $file_name = $package["file_name"] ?? "";
    $created_at = date('Y-m-d H:i:s');

    // Insert the new demo user
    $stmt = $conn->prepare("INSERT INTO demo_users (mobile_number, state_id, default_pack_id, default_pack, validity, file_name, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)");
    if (!$stmt) {
        echo json_encode(["success" => false, "message" => "Database error: " . $conn->error]);
        return;
    }
    $stmt->bind_param("sisssis", $mobile_number, $state_id, $default_pack_id, $default_pack, $default_validity, $file_name, $created_at);

    if ($stmt->execute()) {
        echo json_encode([
            "success" => true,
            "message" => "Demo user added successfully",
            "default_pack" => $default_pack,
            "default_validity" => $default_validity,
            "file_name" => $file_name,
        ]);
    } else {
        echo json_encode(["success" => false, "message" => "Error adding demo user: " . $stmt->error]);
    }
}

addDemoUser($conn);

if ($conn && $conn->ping()) {
    $conn->close();
}
ob_end_flush();
?>