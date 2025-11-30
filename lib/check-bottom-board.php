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

// Get the board_name from the query parameter (optional)
$board_name = isset($_GET['board_name']) ? trim($_GET['board_name']) : null;

try {
    // Prepare the SQL query
    if ($board_name) {
        $sql = "SELECT id, board_name, time_schedule, file_name, duration, start_date, end_date 
                FROM bottom_boards 
                WHERE board_name = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("s", $board_name);
    } else {
        $sql = "SELECT id, board_name, time_schedule, file_name, duration, start_date, end_date 
                FROM bottom_boards";
        $stmt = $conn->prepare($sql);
    }
    
    $stmt->execute();
    $result = $stmt->get_result();

    $packageList = [];

    while ($board = $result->fetch_assoc()) {
        // Decode the time_schedule JSON string into an array
        $timeSlots = json_decode($board['time_schedule'], true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            $timeSlots = [$board['time_schedule']]; // Fallback if JSON decoding fails
        }

        // Add the board to the package list
        $packageList[] = [
            "boardId" => (string)$board['id'],
            "boardName" => $board['board_name'],
            "imageUrl" => "https://sms.mydreamplaytv.com/upload-file.php?file_name=" . urlencode($board['file_name']),
            "timeSlots" => $timeSlots,
            "displayTime" => (int)$board['duration'],
            "startDate" => $board['start_date'] === "0000-00-00" ? null : $board['start_date'],
            "endDate" => $board['end_date'] === "0000-00-00" ? null : $board['end_date']
        ];
    }

    if (empty($packageList)) {
        echo json_encode([
            "success" => false,
            "message" => $board_name ? "No bottom boards found for board_name: $board_name" : "No bottom boards found"
        ]);
        exit;
    }

    $response = [
        "success" => true,
        "message" => "Bottom board data retrieved successfully",
        "data" => [
            "board_name" => $board_name ?? "All boards",
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