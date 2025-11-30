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

function deleteState($conn) {
    $json = file_get_contents("php://input");
    $data = json_decode($json, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        echo json_encode(["success" => false, "message" => "Invalid JSON input"]);
        return;
    }

    if (!isset($data['id']) || empty($data['id'])) {
        echo json_encode(["success" => false, "message" => "State ID is required"]);
        return;
    }

    $id = intval($data['id']);

    // Start a transaction
    $conn->begin_transaction();

    try {
        // Step 1: Delete dependent records from demo_users (based on default_pack_id)
        // First, find all default_packages for this state
        $stmt = $conn->prepare("SELECT id FROM default_packages WHERE state_id = ?");
        if (!$stmt) {
            throw new Exception("Failed to prepare statement for selecting default packages");
        }
        $stmt->bind_param("i", $id);
        $stmt->execute();
        $result = $stmt->get_result();
        $default_package_ids = [];
        while ($row = $result->fetch_assoc()) {
            $default_package_ids[] = $row['id'];
        }
        $stmt->close();

        // Delete demo_users records that reference these default packages
        if (!empty($default_package_ids)) {
            $placeholders = implode(',', array_fill(0, count($default_package_ids), '?'));
            $stmt = $conn->prepare("DELETE FROM demo_users WHERE default_pack_id IN ($placeholders)");
            if (!$stmt) {
                throw new Exception("Failed to prepare statement for deleting demo_users");
            }
            $stmt->bind_param(str_repeat('i', count($default_package_ids)), ...$default_package_ids);
            $stmt->execute();
            $stmt->close();
        }

        // Step 2: Delete demo_users records that directly reference the state
        $stmt = $conn->prepare("DELETE FROM demo_users WHERE state_id = ?");
        if (!$stmt) {
            throw new Exception("Failed to prepare statement for deleting demo_users by state_id");
        }
        $stmt->bind_param("i", $id);
        $stmt->execute();
        $stmt->close();

        // Step 3: Delete the state (this will also cascade to default_packages due to ON DELETE CASCADE)
        $stmt = $conn->prepare("DELETE FROM states WHERE id = ?");
        if (!$stmt) {
            throw new Exception("Failed to prepare statement for deleting state");
        }
        $stmt->bind_param("i", $id);
        $stmt->execute();

        if ($stmt->affected_rows > 0) {
            $conn->commit();
            echo json_encode(["success" => true, "message" => "State deleted successfully"]);
        } else {
            $conn->rollback();
            echo json_encode(["success" => false, "message" => "Error deleting state or state not found"]);
        }

        $stmt->close();
    } catch (Exception $e) {
        $conn->rollback();
        echo json_encode(["success" => false, "message" => "Error deleting state: " . $e->getMessage()]);
    }
}

deleteState($conn);
$conn->close();
?>