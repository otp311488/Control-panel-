<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

require 'db.php'; // Ensure this file correctly sets up $conn

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"]));
}

function deleteBottomBoard($conn) {
    $json = file_get_contents("php://input");
    $data = json_decode($json, true);

    if (!isset($data['id']) || empty($data['id'])) {
        echo json_encode(["success" => false, "message" => "Board ID is required"]);
        return;
    }

    $id = intval($data['id']);

    $stmt = $conn->prepare("DELETE FROM bottom_boards WHERE id = ?");
    $stmt->bind_param("i", $id);
    $stmt->execute();

    if ($stmt->affected_rows > 0) {
        echo json_encode(["success" => true, "message" => "Bottom board deleted successfully"]);
    } else {
        echo json_encode(["success" => false, "message" => "Error deleting bottom board or board not found"]);
    }
}

deleteBottomBoard($conn);
?>