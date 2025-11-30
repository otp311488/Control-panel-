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

function deleteDefaultPackage($conn) {
    $json = file_get_contents("php://input");
    $data = json_decode($json, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        echo json_encode(["success" => false, "message" => "Invalid JSON input"]);
        return;
    }

    if (!isset($data['id']) || empty($data['id'])) {
        echo json_encode(["success" => false, "message" => "Package ID is required"]);
        return;
    }

    $id = intval($data['id']);

    // Start a transaction
    $conn->begin_transaction();

    try {
        // Delete dependent records from demo_users
        $stmt = $conn->prepare("DELETE FROM demo_users WHERE default_pack_id = ?");
        if (!$stmt) {
            throw new Exception("Failed to prepare statement for demo_users deletion");
        }
        $stmt->bind_param("i", $id);
        $stmt->execute();
        $stmt->close();

        // Now delete the default package
        $stmt = $conn->prepare("DELETE FROM default_packages WHERE id = ?");
        if (!$stmt) {
            throw new Exception("Failed to prepare statement for default_packages deletion");
        }
        $stmt->bind_param("i", $id);
        $stmt->execute();

        if ($stmt->affected_rows > 0) {
            $conn->commit();
            echo json_encode(["success" => true, "message" => "Default package deleted successfully"]);
        } else {
            $conn->rollback();
            echo json_encode(["success" => false, "message" => "Error deleting package or package not found"]);
        }

        $stmt->close();
    } catch (Exception $e) {
        $conn->rollback();
        echo json_encode(["success" => false, "message" => "Error deleting default package: " . $e->getMessage()]);
    }
}

deleteDefaultPackage($conn);
$conn->close();
?>