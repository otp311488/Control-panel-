<?php
ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);
ini_set('log_errors', 1);
ini_set('error_log', 'error.log');

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

require 'db.php';

if (!$conn) {
    echo json_encode(["success" => false, "message" => "Database connection failed"]);
    exit;
}

function deletePartnerPackage($conn) {
    $json = file_get_contents("php://input");
    $data = json_decode($json, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        echo json_encode(["success" => false, "message" => "Invalid JSON input"]);
        return;
    }

    if (!isset($data['id']) || empty($data['id'])) {
        echo json_encode(["success" => false, "message" => "Partner package ID is required"]);
        return;
    }

    $id = intval($data['id']);

    try {
        $stmt = $conn->prepare("DELETE FROM partner_packages WHERE id = ?");
        if (!$stmt) {
            throw new Exception("Failed to prepare statement");
        }
        $stmt->bind_param("i", $id);
        $stmt->execute();

        if ($stmt->affected_rows > 0) {
            echo json_encode(["success" => true, "message" => "Partner package deleted successfully"]);
        } else {
            echo json_encode(["success" => false, "message" => "Error deleting partner package or package not found"]);
        }

        $stmt->close();
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => "Error deleting partner package: " . $e->getMessage()]);
    }
}

deletePartnerPackage($conn);
$conn->close();
?>