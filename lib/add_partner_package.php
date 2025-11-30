<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

require 'db.php';

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"]));
}

function addPartnerPackage($conn) {
    $json = file_get_contents("php://input");
    $data = json_decode($json, true);

    if (empty($data['package_name']) || empty($data['partner_id']) || empty($data['partner_code']) || empty($data['file_name'])) {
        echo json_encode(["success" => false, "message" => "All fields are required"]);
        return;
    }

    $package_name = trim($data['package_name']);
    $partner_id = intval($data['partner_id']);
    $partner_code = trim($data['partner_code']);
    $file_name = trim($data['file_name']);

    $stmt = $conn->prepare("INSERT INTO partner_packages (package_name, partner_id, partner_code, file_name) VALUES (?, ?, ?, ?)");
    $stmt->bind_param("siss", $package_name, $partner_id, $partner_code, $file_name);

    if ($stmt->execute()) {
        echo json_encode(["success" => true, "message" => "Partner package added successfully"]);
    } else {
        echo json_encode(["success" => false, "message" => "Error adding package: " . $stmt->error]);
    }
}

addPartnerPackage($conn);
?>