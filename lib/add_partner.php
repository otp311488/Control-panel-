<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

require 'db.php';

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"]));
}

function addPartner($conn) {
    $json = file_get_contents("php://input");
    $data = json_decode($json, true);

    if (empty($data['partner_name']) || empty($data['partner_code']) || empty($data['state_id']) || empty($data['splash_screen']) || empty($data['logos']) || empty($data['board'])) {
        echo json_encode(["success" => false, "message" => "All fields are required"]);
        return;
    }

    $partner_name = trim($data['partner_name']);
    $partner_code = trim($data['partner_code']);
    $state_id = intval($data['state_id']);
    $splash_screen = trim($data['splash_screen']);
    $logos = trim($data['logos']);
    $board = trim($data['board']);
    // [HIGHLIGHT]: registration_date is NOT included in the INSERT below, so the database uses its DEFAULT CURRENT_TIMESTAMP
    // If you wanted to explicitly set it in PHP, you'd add: $registration_date = date('Y-m-d H:i:s');

    $stmt = $conn->prepare("INSERT INTO partners (partner_name, partner_code, state_id, splash_screen, logos, board) VALUES (?, ?, ?, ?, ?, ?)");
    // [HIGHLIGHT]: No registration_date in the column list or bind_param, relying on database default
    $stmt->bind_param("ssisss", $partner_name, $partner_code, $state_id, $splash_screen, $logos, $board);

    if ($stmt->execute()) {
        echo json_encode(["success" => true, "message" => "Partner added successfully"]);
    } else {
        echo json_encode(["success" => false, "message" => "Error adding partner: " . $stmt->error]);
    }
}

addPartner($conn);
?>