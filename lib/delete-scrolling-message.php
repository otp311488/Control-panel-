<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

require 'db.php';

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"]));
}

function deleteScrollingMessage($conn) {
    $json = file_get_contents("php://input");
    $data = json_decode($json, true);

    if (empty($data['id'])) {
        echo json_encode(["success" => false, "message" => "ID is required"]);
        return;
    }

    $id = intval($data['id']);

    $stmt = $conn->prepare("DELETE FROM scrolling_messages WHERE id = ?");
    $stmt->bind_param("i", $id);

    if ($stmt->execute()) {
        echo json_encode(["success" => true, "message" => "Scrolling message deleted successfully"]);
    } else {
        echo json_encode(["success" => false, "message" => "Error deleting message: " . $stmt->error]);
    }
}

deleteScrollingMessage($conn);
?>