<?php
ob_start();
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json"); // Ensure JSON output

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

// Clean up URLs by removing surrounding quotes
function cleanUrl($url) {
    $url = trim($url);
    if (preg_match('/^"(.*)"$/', $url, $matches)) {
        $url = $matches[1];
    }
    return $url;
}

// Parse M3U content and return an array of channels
function parseM3UContent($content) {
    $lines = explode("\n", $content);
    $channels = [];
    $channel = null;

    foreach ($lines as $line) {
        $line = trim($line);
        if (strpos($line, '#EXTINF:') === 0) {
            if ($channel !== null) {
                $channels[] = $channel;
            }

            $channel = [
                "channelId" => "", // Will be assigned later
                "channelName" => "*",
                "channelLogoUrl" => "**",
                "channelmainLogoUrl"=>"*",
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

            preg_match_all('/(\w+)\s*=\s*("([^"]*)"|[^,\s]+)/', $line, $matches, PREG_SET_ORDER);
            foreach ($matches as $match) {
                $key = trim($match[1]);
                $value = isset($match[3]) ? trim($match[3]) : trim($match[2]);
                $channel[$key] = $value;
            }
        } elseif (!empty($line) && $channel !== null) {
            $url = trim($line);
            $url = preg_replace('/^channelPlayUrl\s*=\s*/i', '', $url);
            $url = cleanUrl($url);
            $channel["channelPlayUrl"] = $url;
            $channels[] = $channel;
            $channel = null;
        }
    }

    if ($channel !== null) {
        $channels[] = $channel;
    }

    return $channels;
}

// New function to assign sequential channel IDs
function assignChannelIds($channels) {
    $counter = 1;
    foreach ($channels as &$channel) {
        $channel['channelId'] = (string)$counter; // Cast to string to match JSON format
        $counter++;
    }
    unset($channel); // Unset the reference after the loop
    return $channels;
}

function addDemoUser($conn) {
    if (!$conn) {
        return json_encode(["success" => false, "message" => "Database connection failed"], JSON_UNESCAPED_SLASHES);
    }

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $mobile_number = isset($_GET['mobile_number']) ? trim($_GET['mobile_number']) : '';
        $state_name = isset($_GET['state_name']) ? trim($_GET['state_name']) : '';
    } else {
        $json = file_get_contents("php://input");
        $data = json_decode($json, true);
        $mobile_number = isset($data['mobile_number']) ? trim($data['mobile_number']) : '';
        $state_name = isset($data['state_name']) ? trim($data['state_name']) : '';
    }

    if (empty($mobile_number) || empty($state_name)) {
        return json_encode(["success" => false, "message" => "Mobile number and state name are required"], JSON_UNESCAPED_SLASHES);
    }
    if (!preg_match('/^\d{10}$/', $mobile_number)) {
        return json_encode(["success" => false, "message" => "Mobile number must be 10 digits"], JSON_UNESCAPED_SLASHES);
    }

    $stmt = $conn->prepare("SELECT id FROM states WHERE state_name = ? LIMIT 1");
    if (!$stmt) {
        return json_encode(["success" => false, "message" => "State query preparation failed"], JSON_UNESCAPED_SLASHES);
    }
    $stmt->bind_param("s", $state_name);
    $stmt->execute();
    $result = $stmt->get_result();
    $state = $result->fetch_assoc();

    if (!$state) {
        return json_encode(["success" => false, "message" => "Invalid state name"], JSON_UNESCAPED_SLASHES);
    }
    $state_id = $state['id'];

    $stmt = $conn->prepare("SELECT mobile_number, created_at, validity, default_pack_id FROM demo_users WHERE mobile_number = ?");
    if (!$stmt) {
        return json_encode(["success" => false, "message" => "User query preparation failed"], JSON_UNESCAPED_SLASHES);
    }
    $stmt->bind_param("s", $mobile_number);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $user = $result->fetch_assoc();
        $expiry_date = date('Y-m-d H:i:s', strtotime($user['created_at'] . " +{$user['validity']} hours"));
        $current_date = date('Y-m-d H:i:s');

        if ($current_date <= $expiry_date) {
            $stmt = $conn->prepare("SELECT package_name, file_name FROM default_packages WHERE id = ? LIMIT 1");
            if (!$stmt) {
                return json_encode(["success" => false, "message" => "Package query preparation failed"], JSON_UNESCAPED_SLASHES);
            }
            $stmt->bind_param("i", $user['default_pack_id']);
            $stmt->execute();
            $result = $stmt->get_result();
            $package = $result->fetch_assoc();

            if (!$package) {
                return json_encode(["success" => false, "message" => "No package found for default_pack_id: " . $user['default_pack_id']], JSON_UNESCAPED_SLASHES);
            }

            $default_pack = $package["package_name"] ?? "Default Pack";
            $file_name = $package["file_name"] ?? "";
            error_log("Processing file_name for existing user: $file_name");

            $channels = [];
            if ($file_name) {
                $file_content = fetchFileContent($file_name);
                if ($file_content !== false) {
                    $channels = parseM3UContent($file_content);
                    // Assign dynamic channel IDs
                    $channels = assignChannelIds($channels);
                } else {
                    error_log("Failed to fetch channel file content from path: $file_name");
                    return json_encode(["success" => false, "message" => "Failed to load channel file: $file_name"], JSON_UNESCAPED_SLASHES);
                }
            } else {
                error_log("No file_name specified for package: $default_pack");
            }

            return json_encode([
                "success" => true,
                "message" => "User is active",
                "data" => [
                    "mobile_number" => $mobile_number,
                    "default_pack" => $default_pack,
                    "created_at" => $user['created_at'],
                    "status" => "active",
                    "package_list" => $channels
                ]
            ], JSON_UNESCAPED_SLASHES);
        } else {
            return json_encode([
                "success" => false,
                "message" => "User is expired",
                "data" => [
                    "mobile_number" => $mobile_number,
                    "status" => "expired",
                    "expired_on" => $expiry_date
                ]
            ], JSON_UNESCAPED_SLASHES);
        }
    }

    $stmt = $conn->prepare("SELECT id, package_name, file_name, validity FROM default_packages WHERE state_id = ? LIMIT 1");
    if (!$stmt) {
        return json_encode(["success" => false, "message" => "Package query preparation failed"], JSON_UNESCAPED_SLASHES);
    }
    $stmt->bind_param("i", $state_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $package = $result->fetch_assoc();

    if (!$package) {
        return json_encode(["success" => false, "message" => "No package found for state ID: $state_id"], JSON_UNESCAPED_SLASHES);
    }

    $default_pack_id = $package["id"];
    $default_pack = $package["package_name"] ?? "Default Pack";
    $default_validity = $package["validity"] ?? 24;
    $file_name = $package["file_name"] ?? "";
    $created_at = date('Y-m-d H:i:s');
    error_log("Processing file_name for new user: $file_name");

    $channels = [];
    if ($file_name) {
        $file_content = fetchFileContent($file_name);
        if ($file_content !== false) {
            $channels = parseM3UContent($file_content);
            // Assign dynamic channel IDs
            $channels = assignChannelIds($channels);
        } else {
            error_log("Failed to fetch channel file content from path: $file_name");
            return json_encode(["success" => false, "message" => "Failed to load channel file: $file_name"], JSON_UNESCAPED_SLASHES);
        }
    } else {
        error_log("No file_name specified for package: $default_pack");
    }

    $stmt = $conn->prepare(
        "INSERT INTO demo_users (mobile_number, state_id, default_pack_id, default_pack, validity, file_name, created_at) 
         VALUES (?, ?, ?, ?, ?, ?, ?)"
    );
    if (!$stmt) {
        return json_encode(["success" => false, "message" => "Insert query preparation failed"], JSON_UNESCAPED_SLASHES);
    }
    $stmt->bind_param("sisssss", $mobile_number, $state_id, $default_pack_id, $default_pack, $default_validity, $file_name, $created_at);

    if ($stmt->execute()) {
        return json_encode([
            "success" => true,
            "message" => "Demo user added successfully",
            "data" => [
                "mobile_number" => $mobile_number,
                "default_pack" => $default_pack,
                "default_validity" => $default_validity,
                "created_at" => $created_at,
                "package_list" => $channels
            ]
        ], JSON_UNESCAPED_SLASHES);
    } else {
        return json_encode(["success" => false, "message" => "Error adding demo user: " . $conn->error], JSON_UNESCAPED_SLASHES);
    }
}

echo addDemoUser($conn);
if ($conn && $conn->ping()) {
    $conn->close();
}
ob_end_flush();
?>