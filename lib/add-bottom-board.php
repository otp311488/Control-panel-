<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require 'db.php';

file_put_contents('debug.log', "Request received at " . date('Y-m-d H:i:s') . "\n", FILE_APPEND);

if (!$conn) {
    echo json_encode(["success" => false, "message" => "Database connection failed"]);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["success" => false, "message" => "Only POST requests are allowed"]);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
file_put_contents('debug.log', "Input: " . print_r($input, true) . "\n", FILE_APPEND);

if (!$input || !isset($input['board_name']) || !isset($input['time_schedule']) || !isset($input['file_name']) || !isset($input['duration']) || !isset($input['start_date']) || !isset($input['end_date'])) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Invalid input"]);
    exit;
}

$boardName = $input['board_name'];
$timeSchedule = $input['time_schedule'];
$fileName = $input['file_name'];
$duration = (int)$input['duration'];
$startDate = $input['start_date'];
$endDate = $input['end_date'];

try {
    $sql = "INSERT INTO bottom_boards (board_name, time_schedule, file_name, duration, start_date, end_date) VALUES (?, ?, ?, ?, ?, ?)";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sssiss", $boardName, $timeSchedule, $fileName, $duration, $startDate, $endDate);
    $stmt->execute();

    file_put_contents('debug.log', "Insert successful, ID: " . $conn->insert_id . "\n", FILE_APPEND);
    echo json_encode([
        "success" => true,
        "message" => "Bottom board added successfully",
        "board_id" => $conn->insert_id
    ]);
} catch (Exception $e) {
    file_put_contents('debug.log', "Error: " . $e->getMessage() . "\n", FILE_APPEND);
    echo json_encode(["success" => false, "message" => "Error: " . $e->getMessage()]);
}

$conn->close();
?>