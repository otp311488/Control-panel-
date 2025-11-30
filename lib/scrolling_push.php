<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: text/event-stream");
header("Cache-Control: no-cache");
header("Connection: keep-alive");

require 'db.php'; // Include your database connection file

// Check database connection
if (!$conn) {
    echo "event: error\n";
    echo "data: " . json_encode(["success" => false, "message" => "Database connection failed"]) . "\n\n";
    exit;
}

// Function to send SSE message
function sendSSE($event, $data) {
    echo "event: $event\n";
    echo "data: " . json_encode($data, JSON_UNESCAPED_SLASHES) . "\n\n";
    ob_flush();
    flush();
}

// Main loop to push data based on time
while (true) {
    if (!$conn->ping()) {
        sendSSE("error", ["success" => false, "message" => "Database connection lost"]);
        break;
    }

    $currentTime = date("Y-m-d H:i:s"); // Current server time (e.g., "2025-03-22 14:30:00")

    // Fetch all scrolling messages
    $stmt = $conn->prepare("SELECT id, scrolling_name, script, time_schedule FROM scrolling_messages");
    if (!$stmt) {
        sendSSE("error", ["success" => false, "message" => "Database query preparation failed"]);
        break;
    }
    $stmt->execute();
    $result = $stmt->get_result();

    $scrollsToPush = [];
    while ($scroll = $result->fetch_assoc()) {
        $timeSchedule = json_decode($scroll['time_schedule'], true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            $timeSchedule = [$scroll['time_schedule']]; // Fallback to string if JSON decode fails
        }

        // Check if current time matches any time slot (within a 10-second window)
        foreach ($timeSchedule as $slot) {
            // Convert the time slot to a timestamp
            $slotTime = strtotime($slot);
            $currentTimeStamp = strtotime($currentTime);
            $diffSeconds = abs($currentTimeStamp - $slotTime);

            if ($diffSeconds <= 10) { // Push if within 10 seconds of the scheduled time
                $scrollsToPush[] = [
                    "scrollId" => (string)$scroll['id'],
                    "scrollingName" => $scroll['scrolling_name'],
                    "script" => $scroll['script'],
                    "timeSlot" => $slot,
                    "displayTime" => 5 // Default display time in seconds (adjustable)
                ];
            }
        }
    }

    if (!empty($scrollsToPush)) {
        sendSSE("scrollingPush", [
            "success" => true,
            "message" => "Scrolling data for current time",
            "scrolls" => $scrollsToPush
        ]);
    } else {
        sendSSE("ping", ["message" => "No scrolling messages scheduled for $currentTime"]);
    }

    // Sleep for 10 seconds to check frequently (adjust based on precision needs)
    sleep(10);
}

$conn->close();
?>