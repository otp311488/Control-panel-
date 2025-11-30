<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET");
header("Content-Type: application/json");

require 'db.php';

if (!$conn) {
    echo json_encode(["success" => false, "message" => "Database connection failed"]);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(["success" => false, "message" => "Only GET requests are allowed"]);
    exit;
}

try {
    // Include created_at in the SELECT statement
    $sql = "SELECT id, board_name, time_schedule, file_name, duration, start_date, end_date, created_at FROM bottom_boards";
    $stmt = $conn->prepare($sql);
    $stmt->execute();
    $result = $stmt->get_result();

    $packageList = [];
    $firstBoardName = null;

    while ($board = $result->fetch_assoc()) {
        if ($firstBoardName === null) $firstBoardName = $board['board_name'];
        $timeSlots = json_decode($board['time_schedule'], true);
        if (json_last_error() !== JSON_ERROR_NONE) $timeSlots = [$board['time_schedule']];

        $packageList[] = [
            "boardId" => (string)$board['id'],
            "boardName" => $board['board_name'],
            "imageUrl" => "https://sms.mydreamplaytv.com/upload-file.php?file_name=" . urlencode($board['file_name']),
            "timeSlots" => $timeSlots,
            "displayTime" => (int)$board['duration'],
            "startDate" => $board['start_date'], // e.g., "2025-03-22"
            "endDate" => $board['end_date'],     // e.g., "2025-03-25"
            "createdAt" => $board['created_at']   // Add created_at to the response
        ];
    }

    $response = [
        "success" => true,
        "message" => "Bottom board data retrieved successfully",
        "data" => [
            "board_name" => $firstBoardName ?? "Unknown",
            "package_list" => $packageList
        ]
    ];

    echo json_encode($response, JSON_UNESCAPED_SLASHES);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Error: " . $e->getMessage()]);
}

$conn->close();
?>