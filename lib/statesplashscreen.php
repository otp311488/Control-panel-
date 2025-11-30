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

    // If state_name is provided, fetch the splash screen URL for that state
    if (!empty($state_name)) {
        $stmt = $conn->prepare("SELECT id, state_name, splash_screen FROM states WHERE state_name = ? LIMIT 1");
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
        $splash_screen_url = $splash_screen ? "https://sms.mydreamplaytv.com/upload-file.php?file_name=" . urlencode($splash_screen) : '';

        echo json_encode([
            "success" => true,
            "state" => [
                "id" => $state['id'],
                "state_name" => $state['state_name'],
                "splash_screen" => $splash_screen_url
            ]
        ], JSON_UNESCAPED_SLASHES);
        return;
    }

    // If no state_name is provided, return all states as before
    $result = $conn->query("SELECT id, state_name, splash_screen FROM states ORDER BY state_name ASC");
    if (!$result) {
        echo json_encode(["success" => false, "message" => "Error fetching states: " . $conn->error], JSON_UNESCAPED_SLASHES);
        return;
    }

    $states = [];
    while ($row = $result->fetch_assoc()) {
        $splash_screen = $row['splash_screen'] ?? '';
        $row['splash_screen'] = $splash_screen ? "https://sms.mydreamplaytv.com/upload-file.php?file_name=" . urlencode($splash_screen) : '';
        $states[] = $row;
    }

    if (empty($states)) {
        echo json_encode(["success" => true, "states" => [], "message" => "No states found."], JSON_UNESCAPED_SLASHES);
    } else {
        echo json_encode(["success" => true, "states" => $states], JSON_UNESCAPED_SLASHES);
    }
}

getStates($conn);
$conn->close();
?>