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

// Get the scrolling_name from the query parameter (optional)
$scrolling_name = isset($_GET['scrolling_name']) ? trim($_GET['scrolling_name']) : null;

try {
    // Prepare the SQL query
    if ($scrolling_name) {
        $sql = "SELECT id, scrolling_name, script, time_schedule, duration, start_date, end_date 
                FROM scrolling_messages 
                WHERE scrolling_name = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("s", $scrolling_name);
    } else {
        $sql = "SELECT id, scrolling_name, script, time_schedule, duration, start_date, end_date 
                FROM scrolling_messages";
        $stmt = $conn->prepare($sql);
    }
    
    $stmt->execute();
    $result = $stmt->get_result();

    $messageList = [];

    while ($message = $result->fetch_assoc()) {
        // Decode the time_schedule JSON string into an array
        $timeSlots = json_decode($message['time_schedule'], true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            $timeSlots = [$message['time_schedule']]; // Fallback if JSON decoding fails
        }

        // Add the scrolling message to the message list
        $messageList[] = [
            "messageId" => (string)$message['id'],
            "scrollingName" => $message['scrolling_name'],
            "script" => $message['script'],
            "timeSlots" => $timeSlots,
            "displayTime" => (int)$message['duration'],
            "startDate" => $message['start_date'] === "0000-00-00" ? null : $message['start_date'],
            "endDate" => $message['end_date'] === "0000-00-00" ? null : $message['end_date']
        ];
    }

    if (empty($messageList)) {
        echo json_encode([
            "success" => false,
            "message" => $scrolling_name ? "No scrolling messages found for scrolling_name: $scrolling_name" : "No scrolling messages found"
        ]);
        exit;
    }

    $response = [
        "success" => true,
        "message" => "Scrolling message data retrieved successfully",
        "data" => [
            "scrolling_name" => $scrolling_name ?? "All messages",
            "message_list" => $messageList
        ]
    ];

    echo json_encode($response, JSON_UNESCAPED_SLASHES);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Error: " . $e->getMessage()]);
}

$conn->close();
?>