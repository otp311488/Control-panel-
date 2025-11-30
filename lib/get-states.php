<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

require 'db.php';

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"]));
}

function getStates($conn) {
    $result = $conn->query("SELECT id, state_name, splash_screen FROM states ORDER BY state_name ASC");
    if (!$result) {
        echo json_encode(["success" => false, "message" => "Error fetching states: " . $conn->error]);
        return;
    }

    $states = [];
    while ($row = $result->fetch_assoc()) {
        $states[] = $row;
    }

    if (empty($states)) {
        echo json_encode(["success" => true, "states" => [], "message" => "No states found."]);
    } else {
        echo json_encode(["success" => true, "states" => $states]);
    }
}

getStates($conn);
$conn->close();
?>