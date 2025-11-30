<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

require 'db.php';

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"], JSON_UNESCAPED_SLASHES));
}

function getStates($conn) {
    // Handle OPTIONS request for CORS preflight
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        header("HTTP/1.1 204 No Content");
        exit;
    }

    // Get state_name from GET or POST request
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $state_name = isset($_GET['state_name']) ? trim($_GET['state_name']) : '';
    } else {
        $json = file_get_contents("php://input");
        $data = json_decode($json, true);
        $state_name = isset($data['state_name']) ? trim($data['state_name']) : '';
    }

    // Make state_name required
    if (empty($state_name)) {
        echo json_encode(["success" => false, "message" => "State name is required"], JSON_UNESCAPED_SLASHES);
        return;
    }

    // Fetch the state and its splash screen
    $stmt = $conn->prepare("SELECT splash_screen FROM states WHERE state_name = ? LIMIT 1");
    if (!$stmt) {
        echo json_encode(["success" => false, "message" => "Query preparation failed: " . $conn->error], JSON_UNESCAPED_SLASHES);
        return;
    }
    $stmt->bind_param("s", $state_name);
    $stmt->execute();
    $result = $stmt->get_result();
    $state = $result->fetch_assoc();

    if (!$state) {
        echo json_encode(["success" => false, "message" => "State not found: $state_name"], JSON_UNESCAPED_SLASHES);
        return;
    }

    $splash_screen = $state['splash_screen'] ?? '';
    if (empty($splash_screen)) {
        echo json_encode(["success" => false, "message" => "No splash screen found for state: $state_name"], JSON_UNESCAPED_SLASHES);
        return;
    }

    // Construct and return only the splash screen URL
    $splash_screen_url = "https://sms.mydreamplaytv.com/upload-file.php?file_name=" . urlencode($splash_screen);
    echo json_encode($splash_screen_url, JSON_UNESCAPED_SLASHES);
}

getStates($conn);
$conn->close();
?>