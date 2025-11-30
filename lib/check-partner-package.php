<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

require 'db.php';

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"], JSON_UNESCAPED_SLASHES));
}

// Convert filename to full URL
function getFileUrl($fileName) {
    if (empty($fileName)) {
        return "";
    }
    return "https://sms.mydreamplaytv.com/upload-file.php?file_name=" . urlencode(basename($fileName));
}

// Fetch file content from local filesystem by base name
function fetchFileContent($file_name) {
    $base_dir = $_SERVER['DOCUMENT_ROOT'] . '/uploads/'; // Use lowercase 'uploads'
    error_log("Base directory set to: $base_dir");

    // Check if the directory exists, create it if it doesn't
    if (!file_exists($base_dir)) {
        if (mkdir($base_dir, 0755, true)) {
            error_log("Created directory: $base_dir");
        } else {
            error_log("Error: Failed to create directory: $base_dir");
            return false;
        }
    }

    // Handle the file name, whether it's a URL or a direct file name
    $parsed_url = filter_var($file_name, FILTER_VALIDATE_URL) ? parse_url($file_name, PHP_URL_PATH) : $file_name;
    $full_file_name = basename($parsed_url);
    // Adjust the regex to match a 16-character prefix (as seen in the working code)
    $base_name = preg_replace('/^[0-9a-f]{16}[-_]?/', '', $full_file_name);
    error_log("Extracted base name: $base_name from file_name: $file_name");

    // Look for files matching the pattern
    $files = glob($base_dir . "*_" . $base_name);
    if (empty($files)) {
        // Fallback to full file name if prefix-based search fails
        $files = glob($base_dir . $full_file_name);
    }

    if (!empty($files)) {
        $full_path = $files[0];
        error_log("Found matching file: $full_path");
        $content = file_get_contents($full_path);
        if ($content !== false) {
            error_log("Successfully fetched content from: $full_path - Content length: " . strlen($content));
            // Log the entire file content for debugging
            error_log("Full file content:\n$content");
            return $content;
        } else {
            error_log("Error: Failed to read file content from: $full_path - Check permissions");
            return false;
        }
    } else {
        error_log("Error: No file found in $base_dir with base name: $base_name or full name: $full_file_name");
        return false;
    }
}

// Clean up URLs by removing surrounding quotes
function cleanUrl($url) {
    $url = trim($url);
    if (preg_match('/^"(.*)"$/', $url, $matches)) {
        $url = $matches[1];
    }
    return $url;
}

// Parse M3U content
function parseM3UContent($content) {
    $lines = explode("\n", $content);
    $channels = [];
    $channel = null;

    foreach ($lines as $line) {
        $line = trim($line);
        if (empty($line)) {
            continue; // Skip empty lines
        }

        error_log("Parsing line: $line");

        // Skip lines that start with "stream"
        if (strpos($line, 'stream ') === 0) {
            continue;
        }

        if (strpos($line, '#EXTINF:') === 0) {
            if ($channel !== null) {
                $channels[] = $channel;
            }
            $channel = [
                "channelId" => "",
                "channelName" => "*",
                "channelPlayUrl" => "",
                "audioInfo" => [],
                "channelCategory" => "**",
                "channelLanguage" => "*",
                "categoryId" => "**",
                "languageId" => 0,
                "multiCastUrl" => null,
                "unicastDashUrl" => null,
                "unicastHlsUrl" => null,
                "multiAudio" => false
            ];
            // Parse attributes in #EXTINF line
            preg_match_all('/(\w+)\s*=\s*("([^"]*)"|[^,]+)(?:,|$)/', $line, $matches, PREG_SET_ORDER);
            foreach ($matches as $match) {
                $key = trim($match[1]);
                $value = isset($match[3]) ? trim($match[3]) : trim($match[2]);
                // Remove quotes from the value if present
                $value = trim($value, '"');
                // For unquoted values, take only the part before the next comma or space
                if (strpos($value, ',') !== false) {
                    $value = trim(explode(',', $value)[0]);
                }
                // Skip channelLogoUrl and channelmainLogoUrl (case-insensitive)
                if (strtolower($key) === 'channellogourl' || strtolower($key) === 'channelmainlogourl') {
                    continue;
                }
                // Map attributes to the appropriate fields
                switch ($key) {
                    case 'channelName':
                        $channel["channelName"] = $value;
                        break;
                    case 'channelCategory':
                        $channel["channelCategory"] = $value;
                        break;
                    case 'channelLanguage':
                        $channel["channelLanguage"] = $value;
                        break;
                    case 'categoryId':
                        $channel["categoryId"] = $value;
                        break;
                    case 'languageId':
                        $channel["languageId"] = (int)$value;
                        break;
                    case 'multiCastUrl':
                        $channel["multiCastUrl"] = ($value === 'null') ? null : $value;
                        break;
                    case 'unicastDashUrl':
                        $channel["unicastDashUrl"] = ($value === 'null') ? null : $value;
                        break;
                    case 'unicastHlsUrl':
                        $channel["unicastHlsUrl"] = ($value === 'null') ? null : $value;
                        break;
                    case 'multiAudio':
                        $channel["multiAudio"] = ($value === 'true');
                        break;
                }
                error_log("Parsed attribute: $key = $value");
            }
            error_log("Parsed channel: " . ($channel['channelName'] ?? 'Unknown'));
        } elseif (!empty($line) && $channel !== null) {
            // Handle the channelPlayUrl line
            $url = trim($line);
            $url = preg_replace('/^channelPlayUrl\s*=\s*/i', '', $url);
            $url = cleanUrl($url);
            if (filter_var($url, FILTER_VALIDATE_URL)) {
                $channel["channelPlayUrl"] = $url;
                error_log("Set URL for " . ($channel['channelName'] ?? 'Unknown') . ": $url");
                $channels[] = $channel;
                $channel = null;
            } else {
                error_log("Invalid URL skipped for " . ($channel['channelName'] ?? 'Unknown') . ": $url");
            }
        }
    }
    if ($channel !== null) {
        error_log("Adding leftover channel: " . ($channel['channelName'] ?? 'Unknown'));
        $channels[] = $channel;
    }
    error_log("Total channels parsed: " . count($channels));
    return $channels;
}

// Assign sequential channel IDs
function assignChannelIds($channels) {
    $counter = 1;
    foreach ($channels as &$channel) {
        $channel['channelId'] = (string)$counter;
        $counter++;
    }
    unset($channel);
    return $channels;
}

// Function to handle file fetching and parsing
function fetchAndParseFileData($file_name, $partner_code) {
    $channels = [];
    if (empty($file_name)) {
        error_log("No file_name provided for partner_code: $partner_code");
        return $channels;
    }

    error_log("Attempting to fetch file: $file_name for partner_code: $partner_code");
    $file_content = fetchFileContent($file_name);
    if ($file_content !== false) {
        $channels = parseM3UContent($file_content);
        $channels = assignChannelIds($channels);
        error_log("Successfully parsed " . count($channels) . " channels for file: $file_name");
    } else {
        error_log("No content retrieved for file: $file_name");
    }
    return $channels;
}

function checkPartnerPackage($conn) {
    $method = $_SERVER['REQUEST_METHOD'];

    // Extract parameters based on the request method
    $partner_code = '';
    $package_name = '';
    $file_name = '';
    $partner_id = '';

    if ($method === 'GET') {
        // For GET requests, read from query parameters
        $partner_code = isset($_GET['code']) ? trim($_GET['code']) : '';
        $package_name = isset($_GET['package_name']) ? trim($_GET['package_name']) : '';
        $file_name = isset($_GET['file_name']) ? trim($_GET['file_name']) : '';
    } else {
        // For POST, PUT, DELETE, read from JSON body
        $json = file_get_contents("php://input");
        $data = json_decode($json, true);
        $partner_code = isset($data['code']) ? trim($data['code']) : '';
        $package_name = isset($data['package_name']) ? trim($data['package_name']) : '';
        $file_name = isset($data['file_name']) ? trim($data['file_name']) : '';
        $partner_id = isset($data['partner_id']) ? trim($data['partner_id']) : ''; // For POST requests
    }

    if (empty($partner_code)) {
        error_log("Partner code is missing in request");
        return json_encode(["success" => false, "message" => "Partner code is required"], JSON_UNESCAPED_SLASHES);
    }

    // Partner_id lookup for POST (if not provided in the request body)
    if ($method === 'POST' && empty($partner_id)) {
        $stmt = $conn->prepare("SELECT id FROM partners WHERE partner_code = ?");
        if (!$stmt) {
            error_log("Failed to prepare query to look up partner: " . $conn->error);
            return json_encode(["success" => false, "message" => "Failed to prepare query to look up partner"], JSON_UNESCAPED_SLASHES);
        }
        $stmt->bind_param("s", $partner_code);
        if (!$stmt->execute()) {
            error_log("Failed to execute query to look up partner: " . $stmt->error);
            return json_encode(["success" => false, "message" => "Failed to execute query to look up partner"], JSON_UNESCAPED_SLASHES);
        }
        $result = $stmt->get_result();
        $partner = $result->fetch_assoc();

        if (!$partner) {
            error_log("Partner with code '$partner_code' does not exist");
            return json_encode(["success" => false, "message" => "Partner with code '$partner_code' does not exist"], JSON_UNESCAPED_SLASHES);
        }

        $partner_id = $partner['id'];
        error_log("Found partner_id: $partner_id for partner_code: $partner_code");
    }

    if ($method === 'GET') {
        $stmt = $conn->prepare("SELECT package_name, file_name FROM partner_packages WHERE partner_code = ? LIMIT 1");
        if (!$stmt) {
            error_log("Database query preparation failed: " . $conn->error);
            return json_encode(["success" => false, "message" => "Database query preparation failed"], JSON_UNESCAPED_SLASHES);
        }
        $stmt->bind_param("s", $partner_code);
        $stmt->execute();
        $result = $stmt->get_result();
        $package = $result->fetch_assoc();

        if (!$package) {
            error_log("Partner package does not exist for partner_code: $partner_code");
            return json_encode(["success" => false, "message" => "Partner package does not exist"], JSON_UNESCAPED_SLASHES);
        }

        $default_pack = $package["package_name"];
        $file_name = $package["file_name"] ?: $file_name;
        if (empty($file_name)) {
            error_log("No file_name available for partner_code: $partner_code");
            return json_encode([
                "success" => false,
                "message" => "No file_name available for this partner package"
            ], JSON_UNESCAPED_SLASHES);
        }

        error_log("Using file_name: $file_name for partner_code: $partner_code");
        $channels = fetchAndParseFileData($file_name, $partner_code);

        // Prepare the response
        $response = [
            "success" => true,
            "message" => "Package data retrieved successfully",
            "data" => [
                "default_pack" => $default_pack,
                "package_list" => $channels
            ]
        ];

        // Final check to ensure channelmainLogoUrl is not present (case-insensitive)
        foreach ($response['data']['package_list'] as &$channel) {
            foreach ($channel as $key => $value) {
                if (strtolower($key) === 'channellogourl' || strtolower($key) === 'channelmainlogourl') {
                    unset($channel[$key]);
                }
            }
        }
        unset($channel);

        return json_encode($response, JSON_UNESCAPED_SLASHES);
    } elseif ($method === 'POST') {
        if (empty($package_name)) {
            $package_name = "default_package_" . $partner_code;
            error_log("No package_name provided for partner_code: $partner_code, using default: $package_name");
        }

        if (empty($partner_id)) {
            error_log("Partner ID is required for POST request");
            return json_encode(["success" => false, "message" => "Partner ID is required"], JSON_UNESCAPED_SLASHES);
        }

        $stmt = $conn->prepare("SELECT partner_code FROM partner_packages WHERE partner_code = ?");
        if (!$stmt) {
            error_log("Database query preparation failed: " . $conn->error);
            return json_encode(["success" => false, "message" => "Database query preparation failed"], JSON_UNESCAPED_SLASHES);
        }
        $stmt->bind_param("s", $partner_code);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result->num_rows > 0) {
            error_log("Partner package already exists for partner_code: $partner_code");
            return json_encode(["success" => false, "message" => "Partner package already exists"], JSON_UNESCAPED_SLASHES);
        }

        $stmt = $conn->prepare("INSERT INTO partner_packages (partner_id, partner_code, package_name, file_name) VALUES (?, ?, ?, ?)");
        if (!$stmt) {
            error_log("Database insert query preparation failed: " . $conn->error);
            return json_encode(["success" => false, "message" => "Database insert query preparation failed"], JSON_UNESCAPED_SLASHES);
        }
        $stmt->bind_param("isss", $partner_id, $partner_code, $package_name, $file_name);

        if ($stmt->execute()) {
            $stmt = $conn->prepare("SELECT package_name, file_name FROM partner_packages WHERE partner_code = ? LIMIT 1");
            if (!$stmt) {
                error_log("Database query preparation failed after insert: " . $conn->error);
                return json_encode(["success" => false, "message" => "Database query preparation failed after insert"], JSON_UNESCAPED_SLASHES);
            }
            $stmt->bind_param("s", $partner_code);
            $stmt->execute();
            $result = $stmt->get_result();
            $package = $result->fetch_assoc();

            if (!$package) {
                error_log("Partner package does not exist after insert for partner_code: $partner_code");
                return json_encode(["success" => false, "message" => "Partner package does not exist after insert"], JSON_UNESCAPED_SLASHES);
            }

            $default_pack = $package["package_name"];
            $file_name = $package["file_name"] ?: $file_name;
            if (empty($file_name)) {
                error_log("No file_name available for partner_code: $partner_code");
                return json_encode([
                    "success" => false,
                    "message" => "No file_name available for this partner package"
                ], JSON_UNESCAPED_SLASHES);
            }

            error_log("Using file_name: $file_name for partner_code: $partner_code");
            $channels = fetchAndParseFileData($file_name, $partner_code);

            // Prepare the response
            $response = [
                "success" => true,
                "message" => "Partner package added successfully",
                "data" => [
                    "default_pack" => $default_pack,
                    "package_list" => $channels
                ]
            ];

            // Final check to ensure channelmainLogoUrl is not present (case-insensitive)
            foreach ($response['data']['package_list'] as &$channel) {
                foreach ($channel as $key => $value) {
                    if (strtolower($key) === 'channellogourl' || strtolower($key) === 'channelmainlogourl') {
                        unset($channel[$key]);
                    }
                }
            }
            unset($channel);

            return json_encode($response, JSON_UNESCAPED_SLASHES);
        } else {
            error_log("Error adding partner package: " . $conn->error);
            return json_encode(["success" => false, "message" => "Error adding partner package: " . $conn->error], JSON_UNESCAPED_SLASHES);
        }
    } elseif ($method === 'PUT') {
        if (empty($package_name)) {
            $package_name = "default_package_" . $partner_code;
            error_log("No package_name provided for partner_code: $partner_code, using default: $package_name");
        }

        // Check if the partner package exists
        $stmt = $conn->prepare("SELECT package_name FROM partner_packages WHERE partner_code = ?");
        if (!$stmt) {
            error_log("Database query preparation failed: " . $conn->error);
            return json_encode(["success" => false, "message" => "Database query preparation failed"], JSON_UNESCAPED_SLASHES);
        }
        $stmt->bind_param("s", $partner_code);
        $stmt->execute();
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();

        if (!$row) {
            error_log("Partner package does not exist for partner_code: $partner_code");
            return json_encode(["success" => false, "message" => "Partner package does not exist"], JSON_UNESCAPED_SLASHES);
        }

        $stmt = $conn->prepare("UPDATE partner_packages SET package_name = ?, file_name = ? WHERE partner_code = ?");
        if (!$stmt) {
            error_log("Database update query preparation failed: " . $conn->error);
            return json_encode(["success" => false, "message" => "Database update query preparation failed"], JSON_UNESCAPED_SLASHES);
        }
        $stmt->bind_param("sss", $package_name, $file_name, $partner_code);

        if ($stmt->execute()) {
            $stmt = $conn->prepare("SELECT package_name, file_name FROM partner_packages WHERE partner_code = ? LIMIT 1");
            if (!$stmt) {
                error_log("Database query preparation failed after update: " . $conn->error);
                return json_encode(["success" => false, "message" => "Database query preparation failed after update"], JSON_UNESCAPED_SLASHES);
            }
            $stmt->bind_param("s", $partner_code);
            $stmt->execute();
            $result = $stmt->get_result();
            $package = $result->fetch_assoc();

            if (!$package) {
                error_log("Partner package does not exist after update for partner_code: $partner_code");
                return json_encode(["success" => false, "message" => "Partner package does not exist after update"], JSON_UNESCAPED_SLASHES);
            }

            $default_pack = $package["package_name"];
            $file_name = $package["file_name"] ?: $file_name;
            if (empty($file_name)) {
                error_log("No file_name available for partner_code: $partner_code");
                return json_encode([
                    "success" => false,
                    "message" => "No file_name available for this partner package"
                ], JSON_UNESCAPED_SLASHES);
            }

            error_log("Using file_name: $file_name for partner_code: $partner_code");
            $channels = fetchAndParseFileData($file_name, $partner_code);

            // Prepare the response
            $response = [
                "success" => true,
                "message" => "Partner package updated successfully",
                "data" => [
                    "default_pack" => $default_pack,
                    "package_list" => $channels
                ]
            ];

            // Final check to ensure channelmainLogoUrl is not present (case-insensitive)
            foreach ($response['data']['package_list'] as &$channel) {
                foreach ($channel as $key => $value) {
                    if (strtolower($key) === 'channellogourl' || strtolower($key) === 'channelmainlogourl') {
                        unset($channel[$key]);
                    }
                }
            }
            unset($channel);

            return json_encode($response, JSON_UNESCAPED_SLASHES);
        } else {
            error_log("Error updating partner package: " . $conn->error);
            return json_encode(["success" => false, "message" => "Error updating partner package: " . $conn->error], JSON_UNESCAPED_SLASHES);
        }
    } elseif ($method === 'DELETE') {
        $stmt = $conn->prepare("DELETE FROM partner_packages WHERE partner_code = ?");
        if (!$stmt) {
            error_log("Database delete query preparation failed: " . $conn->error);
            return json_encode(["success" => false, "message" => "Database delete query preparation failed"], JSON_UNESCAPED_SLASHES);
        }
        $stmt->bind_param("s", $partner_code);

        if ($stmt->execute()) {
            return json_encode(["success" => true, "message" => "Partner package deleted successfully"], JSON_UNESCAPED_SLASHES);
        } else {
            error_log("Error deleting partner package: " . $conn->error);
            return json_encode(["success" => false, "message" => "Error deleting partner package: " . $conn->error], JSON_UNESCAPED_SLASHES);
        }
    }

    error_log("Invalid request method: $method");
    return json_encode(["success" => false, "message" => "Invalid request method"], JSON_UNESCAPED_SLASHES);
}

echo checkPartnerPackage($conn);

if ($conn && $conn->ping()) {
    $conn->close();
}
?>