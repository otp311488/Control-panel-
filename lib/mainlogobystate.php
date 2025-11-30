<?php
ob_start();
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

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
        $full_path = $files[0];
        error_log("Found matching file: $full_path");
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
                // Only add the channel if channelmainLogoUrl is not "**"
                if ($channel["channelmainLogoUrl"] !== "**") {
                    $channels[] = $channel;
                }
            }

            // Initialize channel with only the fields we want
            $channel = [
                "channelName" => "*",
                "channelmainLogoUrl" => "**"
            ];

            // Log the raw EXTINF line for debugging
            error_log("Parsing EXTINF line: $line");

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

            // Extract channelName from the end of the EXTINF line (after the comma) if not already set
            if ($channel["channelName"] === "*" && preg_match('/,\s*(.+)$/', $line, $name_match)) {
                $channel["channelName"] = trim($name_match[1]);
            }

            // Add the channel to the array immediately after parsing #EXTINF, but only if channelmainLogoUrl is not "**"
            if ($channel["channelmainLogoUrl"] !== "**") {
                $channels[] = $channel;
            }
            $channel = null; // Reset channel to avoid duplicate entries
        }
    }

    return $channels;
}

// Main API logic
function getChannelLogoByState($conn) {
    if (!$conn) {
        return json_encode(["success" => false, "message" => "Database connection failed"], JSON_UNESCAPED_SLASHES);
    }

    // Get partner_code from GET parameters
    $partner_code = isset($_GET['partner_code']) ? trim($_GET['partner_code']) : '';
    error_log("Received partner_code: $partner_code");

    if (empty($partner_code)) {
        return json_encode(["success" => false, "message" => "partner_code is required"], JSON_UNESCAPED_SLASHES);
    }

    // Fetch the package file associated with the partner_code
    $stmt = $conn->prepare("SELECT file_name FROM partner_packages WHERE partner_code = ? LIMIT 1");
    if (!$stmt) {
        error_log("Package query preparation failed: " . $conn->error);
        return json_encode(["success" => false, "message" => "Package query preparation failed: " . $conn->error], JSON_UNESCAPED_SLASHES);
    }
    $stmt->bind_param("s", $partner_code); // Bind as string
    if (!$stmt->execute()) {
        error_log("Query execution failed: " . $stmt->error);
        return json_encode(["success" => false, "message" => "Query execution failed: " . $stmt->error], JSON_UNESCAPED_SLASHES);
    }
    $result = $stmt->get_result();
    $package = $result->fetch_assoc();

    if (!$package || empty($package['file_name'])) {
        error_log("No package file found for partner_code: $partner_code");
        // Log the entire result for debugging
        error_log("Query result: " . json_encode($package));
        return json_encode(["success" => false, "message" => "No package file found for partner_code: $partner_code"], JSON_UNESCAPED_SLASHES);
    }

    $file_name = $package['file_name'];
    error_log("Processing file_name: $file_name");

    // Fetch and parse the file
    $channels = [];
    $file_content = fetchFileContent($file_name);
    if ($file_content !== false) {
        $channels = parseM3UContent($file_content);
    } else {
        error_log("Failed to fetch channel file content from path: $file_name");
        return json_encode(["success" => false, "message" => "Failed to load channel file: $file_name"], JSON_UNESCAPED_SLASHES);
    }

    // Return the parsed channels
    return json_encode([
        "success" => true,
        "message" => "Channels retrieved successfully",
        "data" => $channels
    ], JSON_UNESCAPED_SLASHES);
}

// Execute the API function
echo getChannelLogoByState($conn);
if ($conn && $conn->ping()) {
    $conn->close();
}
ob_end_flush();
?>