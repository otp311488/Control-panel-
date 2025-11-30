<?php
ob_start();
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");
header("Cache-Control: no-store, no-cache, must-revalidate, max-age=0"); // Prevent caching
header("Pragma: no-cache");
header("Expires: 0");

require 'db.php';

// Fetch file content from local filesystem by base name
function fetchFileContent($file_name) {
    $base_dir = $_SERVER['DOCUMENT_ROOT'] . '/uploads/';
    error_log("Base directory set to: $base_dir");

    if (!file_exists($base_dir)) {
        if (mkdir($base_dir, 0755, true)) {
            error_log("Created directory: $base_dir");
        } else {
            error_log("Error: Failed to create directory: $base_dir");
            return false;
        }
    }

    $parsed_url = parse_url($file_name, PHP_URL_PATH);
    $full_file_name = basename($parsed_url);
    $base_name = preg_replace('/^[0-9a-f]{13}_/', '', $full_file_name);
    error_log("Extracted base name: $base_name from URL: $file_name");

    $files = glob($base_dir . "*_" . $base_name);
    if (!empty($files)) {
        // Sort files by modification time to get the latest one
        usort($files, function($a, $b) {
            return filemtime($b) - filemtime($a);
        });
        $full_path = $files[0]; // Get the most recently modified file
        error_log("Found matching file: $full_path, last modified: " . date('Y-m-d H:i:s', filemtime($full_path)));
        
        $content = file_get_contents($full_path);
        if ($content !== false) {
            error_log("Successfully fetched content from: $full_path - Content length: " . strlen($content));
            return $content;
        } else {
            error_log("Error: Failed to read file content from: $full_path - Check permissions");
            return false;
        }
    } else {
        error_log("Error: No file found in $base_dir with base name: $base_name");
        return false;
    }
}

// Parse M3U content and return an array of channels with only channelName and channelmainLogoUrl
function parseM3UContent($content) {
    $lines = explode("\n", $content);
    $channels = [];
    $channel = null;

    foreach ($lines as $line) {
        $line = trim($line);
        if (strpos($line, '#EXTINF:') === 0) {
            if ($channel !== null) {
                // Only add the channel if channelmainLogoUrl is not empty or "*"
                if (!empty($channel["channelmainLogoUrl"]) && $channel["channelmainLogoUrl"] !== "*") {
                    $channels[] = $channel;
                }
            }

            // Initialize channel with only the fields we want
            $channel = [
                "channelName" => "*",
                "channelmainLogoUrl" => "*"
            ];

            // Extract channelName and channelmainLogoUrl
            preg_match_all('/(\w+)\s*=\s*("([^"]*)"|[^,\s]+)/', $line, $matches, PREG_SET_ORDER);
            foreach ($matches as $match) {
                $key = trim($match[1]);
                $value = isset($match[3]) ? trim($match[3]) : trim($match[2]);

                // Map channelName and channelmainLogoUrl directly
                if ($key === "channelName") {
                    $channel["channelName"] = $value;
                } elseif ($key === "channelmainLogoUrl") {
                    $channel["channelmainLogoUrl"] = $value;
                }
                // Ignore all other fields
            }
        }
    }

    // Add the last channel if it exists and has a valid channelmainLogoUrl
    if ($channel !== null) {
        if (!empty($channel["channelmainLogoUrl"]) && $channel["channelmainLogoUrl"] !== "*") {
            $channels[] = $channel;
        }
    }

    return $channels;
}

// Main API logic
function getChannelLogoByState($conn) {
    if (!$conn) {
        return json_encode(["success" => false, "message" => "Database connection failed"], JSON_UNESCAPED_SLASHES);
    }

    // Get state_name from GET parameters
    $state_name = isset($_GET['state_name']) ? trim($_GET['state_name']) : '';
    if (empty($state_name)) {
        return json_encode(["success" => false, "message" => "State name is required"], JSON_UNESCAPED_SLASHES);
    }

    // Fetch state ID from the database
    $stmt = $conn->prepare("SELECT id FROM states WHERE state_name = ? LIMIT 1");
    if (!$stmt) {
        return json_encode(["success" => false, "message" => "State query preparation failed"], JSON_UNESCAPED_SLASHES);
    }
    $stmt->bind_param("s", $state_name);
    $stmt->execute();
    $result = $stmt->get_result();
    $state = $result->fetch_assoc();

    if (!$state) {
        return json_encode(["success" => false, "message" => "Invalid state name: $state_name"], JSON_UNESCAPED_SLASHES);
    }
    $state_id = $state['id'];
    error_log("State ID for state_name '$state_name': $state_id");

    // Fetch the package file associated with the state
    $stmt = $conn->prepare("SELECT file_name FROM default_packages WHERE state_id = ? LIMIT 1");
    if (!$stmt) {
        return json_encode(["success" => false, "message" => "Package query preparation failed"], JSON_UNESCAPED_SLASHES);
    }
    $stmt->bind_param("i", $state_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $package = $result->fetch_assoc();

    if (!$package || empty($package['file_name'])) {
        return json_encode(["success" => false, "message" => "No package file found for state ID: $state_id"], JSON_UNESCAPED_SLASHES);
    }

    $file_name = $package['file_name'];
    error_log("Processing file_name: $file_name");

    // Fetch and parse the file
    $channels = [];
    $file_content = fetchFileContent($file_name);
    if ($file_content !== false) {
        $channels = parseM3UContent($file_content);
        error_log("Parsed " . count($channels) . " channels from file: $file_name");
    } else {
        error_log("Failed to fetch channel file content from path: $file_name");
        return json_encode(["success" => false, "message" => "Failed to load channel file: $file_name"], JSON_UNESCAPED_SLASHES);
    }

    // Return the parsed channels
    return json_encode([
        "success" => true,
        "message" => "Channels retrieved successfully",
        "data" => $channels,
        "debug" => [
            "state_name" => $state_name,
            "state_id" => $state_id,
            "file_name" => $file_name,
            "timestamp" => date('Y-m-d H:i:s')
        ]
    ], JSON_UNESCAPED_SLASHES);
}

// Execute the API function
echo getChannelLogoByState($conn);
if ($conn && $conn->ping()) {
    $conn->close();
}
ob_end_flush();
?>