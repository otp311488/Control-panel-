<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

// Handle CORS pre-flight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require 'db.php';

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
if (!$input || !isset($input['id']) || !isset($input['board_name']) || !isset($input['time_schedule']) || !isset($input['file_name']) || !isset($input['duration']) || !isset($input['start_date']) || !isset($input['end_date'])) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Invalid input"]);
    exit;
}

$id = $input['id'];
$boardName = $input['board_name'];
$timeSchedule = $input['time_schedule'];
$fileName = $input['file_name'];
$duration = (int)$input['duration'];
$startDate = $input['start_date'];
$endDate = $input['end_date'];

// Validate dates
if (!DateTime::createFromFormat('Y-m-d', $startDate) || !DateTime::createFromFormat('Y-m-d', $endDate)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Invalid date format. Use YYYY-MM-DD"]);
    exit;
}

try {
    $sql = "UPDATE bottom_boards SET board_name = ?, time_schedule = ?, file_name = ?, duration = ?, start_date = ?, end_date = ? WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sssissi", $boardName, $timeSchedule, $fileName, $duration, $startDate, $endDate, $id);
    $stmt->execute();

    if ($stmt->affected_rows > 0) {
        echo json_encode(["success" => true, "message" => "Bottom board updated successfully"]);
    } else {
        echo json_encode(["success" => false, "message" => "No board found with ID: $id"]);
    }

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Error: " . $e->getMessage()]);
}

$conn->close();
?>