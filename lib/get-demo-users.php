<?php
ob_start();
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

require 'db.php';

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"]));
}

function getDemoUsers($conn) {
    $result = $conn->query("SELECT id, device_ids, mobile_number, reg_date, validity, state_id, default_pack, file_name, created_at, added_at, splash_screen FROM demo_users ORDER BY created_at DESC");

    if (!$result) {
        echo json_encode(["success" => false, "message" => "Error fetching demo users: " . $conn->error]);
        return;
    }

    $users = [];
    while ($row = $result->fetch_assoc()) {
        $users[] = $row;
    }

    echo json_encode([
        "success" => true,
        "users" => $users,
        "message" => empty($users) ? "No demo users found" : ""
    ]);
}

getDemoUsers($conn);

if ($conn && $conn->ping()) {
    $conn->close();
}
ob_end_flush();
?>