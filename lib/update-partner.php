<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

require 'db.php';

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"]));
}

function updatePartner($conn) {
    $json = file_get_contents("php://input");
    $data = json_decode($json, true);

    if (empty($data['id']) || empty($data['partner_name']) || empty($data['partner_code']) || empty($data['state_id'])) {
        echo json_encode(["success" => false, "message" => "All fields (id, partner_name, partner_code, state_id) are required"]);
        return;
    }

    $id = intval($data['id']);
    $partner_name = trim($data['partner_name']);
    $partner_code = trim($data['partner_code']);
    $state_id = intval($data['state_id']);
    $splash_screen = isset($data['splash_screen']) ? trim($data['splash_screen']) : null;
    $logos = isset($data['logos']) ? trim($data['logos']) : null;
    $board = isset($data['board']) ? trim($data['board']) : null;

    // Check if the partner exists
    $stmt = $conn->prepare("SELECT * FROM partners WHERE id = ?");
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        echo json_encode(["success" => false, "message" => "Partner not found"]);
        return;
    }

    // Update the partner
    $stmt = $conn->prepare("UPDATE partners SET partner_name = ?, partner_code = ?, state_id = ?, splash_screen = ?, logos = ?, board = ? WHERE id = ?");
    $stmt->bind_param("ssisssi", $partner_name, $partner_code, $state_id, $splash_screen, $logos, $board, $id);

    if ($stmt->execute()) {
        echo json_encode(["success" => true, "message" => "Partner updated successfully"]);
    } else {
        echo json_encode(["success" => false, "message" => "Error updating partner: " . $stmt->error]);
    }
}

updatePartner($conn);
?>