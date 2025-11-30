<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

require 'db.php';

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"]));
}

function getScrollingMessages($conn) {
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        exit; // Handle CORS preflight
    }

    // Include created_at in the SELECT statement
    $result = $conn->query("SELECT id, scrolling_name, script, time_schedule, duration, start_date, end_date, created_at FROM scrolling_messages ORDER BY created_at DESC");
    $messages = [];

    if ($result) {
        while ($row = $result->fetch_assoc()) {
            $messages[] = $row;
        }
        echo json_encode(["success" => true, "messages" => $messages]);
    } else {
        echo json_encode(["success" => false, "message" => "Error fetching scrolling messages: " . $conn->error]);
    }
}

getScrollingMessages($conn);
$conn->close();
?>