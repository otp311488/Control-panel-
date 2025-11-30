<?php
ob_start();
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

require 'db.php';
require 'demo_file_processor.php';
require 'demo_m3u_reader.php';

if (!$conn) {
    error_log("Database connection failed");
    die(json_encode(["success" => false, "message" => "Database connection failed"], JSON_UNESCAPED_SLASHES));
}

// Main CRUD Operations (GET, POST, PUT)
function manageDemoUser($conn) {
    $method = $_SERVER['REQUEST_METHOD'];
    $device_limit = 2;

    // Input handling
    if ($method === 'GET' || $method === 'POST' || $method === 'PUT') {
        $mobile_number = isset($_GET['mobile_number']) ? trim($_GET['mobile_number']) : '';
        $state_name = isset($_GET['state_name']) ? trim($_GET['state_name']) : '';
        $device_id = isset($_GET['deviceid']) ? trim($_GET['deviceid']) : '';
        // For PUT, also check request body for validity
        if ($method === 'PUT') {
            $json = file_get_contents("php://input");
            $data = json_decode($json, true);
            $mobile_number = isset($data['mobile_number']) ? trim($data['mobile_number']) : $mobile_number;
            $state_name = isset($data['state_name']) ? trim($data['state_name']) : $state_name;
            $device_id = isset($data['deviceid']) ? trim($data['deviceid']) : $device_id;
            $new_validity = isset($data['validity']) ? intval($data['validity']) : null;
        }
    } else {
        $json = file_get_contents("php://input");
        $data = json_decode($json, true);
        $mobile_number = isset($data['mobile_number']) ? trim($data['mobile_number']) : '';
        $state_name = isset($data['state_name']) ? trim($data['state_name']) : '';
        $device_id = isset($data['deviceid']) ? trim($data['deviceid']) : '';
    }

    if (empty($mobile_number)) {
        return json_encode(["success" => false, "message" => "Mobile number is required"], JSON_UNESCAPED_SLASHES);
    }

    // Device management for GET, POST, PUT
    if ($method === 'POST' || $method === 'GET' || $method === 'PUT') {
        if (empty($device_id)) {
            return json_encode(["success" => false, "message" => "Device ID is required"], JSON_UNESCAPED_SLASHES);
        }

        $stmt = $conn->prepare("SELECT device_ids FROM demo_users WHERE mobile_number = ?");
        $stmt->bind_param("s", $mobile_number);
        $stmt->execute();
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();

        $devices = $row && !empty($row['device_ids']) ? explode(',', $row['device_ids']) : [];
        $devices = array_filter($devices, 'trim');

        if (!in_array($device_id, $devices)) {
            if (count($devices) >= $device_limit) {
                return json_encode(["success" => false, "message" => "Device limit exceeded (max $device_limit devices)"], JSON_UNESCAPED_SLASHES);
            }
            $devices[] = $device_id;
            $new_device_ids = implode(',', $devices);

            $stmt = $conn->prepare("UPDATE demo_users SET device_ids = ? WHERE mobile_number = ?");
            $stmt->bind_param("ss", $new_device_ids, $mobile_number);
            $stmt->execute();
        } else {
            $new_device_ids = implode(',', $devices);
        }
    }

    // GET - Retrieve user info or create if not exists
    if ($method === 'GET') {
        $stmt = $conn->prepare("SELECT mobile_number, created_at, validity, default_pack_id, device_ids FROM demo_users WHERE mobile_number = ?");
        $stmt->bind_param("s", $mobile_number);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result->num_rows > 0) {
            $user = $result->fetch_assoc();
            $expiry_date = date('Y-m-d H:i:s', strtotime($user['created_at'] . " +{$user['validity']} hours"));
            $current_date = date('Y-m-d H:i:s');

            if ($current_date <= $expiry_date) {
                $stmt = $conn->prepare("SELECT package_name, file_name FROM default_packages WHERE id = ? LIMIT 1");
                $stmt->bind_param("i", $user['default_pack_id']);
                $stmt->execute();
                $result = $stmt->get_result();
                $package = $result->fetch_assoc();

                $default_pack = $package["package_name"] ?? "Default Pack";
                $file_name = $package["file_name"] ?? "";
                error_log("GET - Retrieved file_name from default_packages: $file_name");

                if (empty($file_name) || !file_exists($file_name)) {
                    error_log("GET - No valid file_name for default_pack_id: {$user['default_pack_id']}");
                    return json_encode([
                        "success" => false,
                        "message" => "No valid M3U file available for this package"
                    ], JSON_UNESCAPED_SLASHES);
                }

                $channels = $file_name ? parseDemoM3UContent(fetchDemoFileContent($file_name)) : [];
                $channels = assignDemoChannelIds($channels);

                foreach ($channels as &$channel) {
                    unset($channel['channelLogoUrl']);
                    unset($channel['channelMainLogoUrl']);
                }
                unset($channel);

                $response = [
                    "success" => true,
                    "message" => "User is active",
                    "data" => [
                        "mobile_number" => $mobile_number,
                        "default_pack" => $default_pack,
                        "created_at" => $user['created_at'],
                        "validity_date" => $expiry_date,
                        "status" => "active",
                        "device_ids" => $user['device_ids'],
                        "package_list" => $channels
                    ]
                ];

                error_log("GET response: " . json_encode($response, JSON_UNESCAPED_SLASHES));
                return json_encode($response, JSON_UNESCAPED_SLASHES);
            }
            return json_encode([
                "success" => false,
                "message" => "User is expired",
                "data" => [
                    "mobile_number" => $mobile_number,
                    "status" => "expired",
                    "expired_on" => $expiry_date,
                    "device_ids" => $user['device_ids']
                ]
            ], JSON_UNESCAPED_SLASHES);
        } else {
            if (empty($state_name)) return json_encode(["success" => false, "message" => "State name is required"], JSON_UNESCAPED_SLASHES);
            if (!preg_match('/^\d{10}$/', $mobile_number)) return json_encode(["success" => false, "message" => "Mobile number must be 10 digits"], JSON_UNESCAPED_SLASHES);

            $stmt = $conn->prepare("SELECT id FROM states WHERE state_name = ? LIMIT 1");
            $stmt->bind_param("s", $state_name);
            $stmt->execute();
            $state = $stmt->get_result()->fetch_assoc();
            if (!$state) return json_encode(["success" => false, "message" => "Invalid state name"], JSON_UNESCAPED_SLASHES);
            $state_id = $state['id'];

            $stmt = $conn->prepare("SELECT id, package_name, file_name, validity FROM default_packages WHERE state_id = ? LIMIT 1");
            $stmt->bind_param("i", $state_id);
            $stmt->execute();
            $package = $stmt->get_result()->fetch_assoc();
            if (!$package) return json_encode(["success" => false, "message" => "No package found for state"], JSON_UNESCAPED_SLASHES);

            $default_pack_id = $package["id"];
            $default_pack = $package["package_name"] ?? "Default Pack";
            $default_validity = $package["validity"] ?? 24;
            $file_name = $package["file_name"] ?? "";
            $created_at = date('Y-m-d H:i:s');
            $device_ids = $device_id;
            $validity_date = date('Y-m-d H:i:s', strtotime("$created_at +{$default_validity} hours"));
            error_log("GET - Retrieved file_name for new user: $file_name");

            if (empty($file_name) || !file_exists($file_name)) {
                error_log("GET - No valid file_name for state_id: $state_id");
                return json_encode([
                    "success" => false,
                    "message" => "No valid M3U file available for this package"
                ], JSON_UNESCAPED_SLASHES);
            }

            $channels = $file_name ? parseDemoM3UContent(fetchDemoFileContent($file_name)) : [];
            $channels = assignDemoChannelIds($channels);

            foreach ($channels as &$channel) {
                unset($channel['channelLogoUrl']);
                unset($channel['channelMainLogoUrl']);
            }
            unset($channel);

            $response = [
                "success" => true,
                "message" => "Demo user added successfully",
                "data" => [
                    "mobile_number" => $mobile_number,
                    "default_pack" => $default_pack,
                    "default_validity" => $default_validity,
                    "created_at" => $created_at,
                    "validity_date" => $validity_date,
                    "device_ids" => $device_ids,
                    "package_list" => $channels
                ]
            ];

            $stmt = $conn->prepare("INSERT INTO demo_users (mobile_number, state_id, default_pack_id, default_pack, validity, file_name, created_at, device_ids) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
            $stmt->bind_param("sissssss", $mobile_number, $state_id, $default_pack_id, $default_pack, $default_validity, $file_name, $created_at, $device_ids);

            if ($stmt->execute()) {
                error_log("GET (new user) response: " . json_encode($response, JSON_UNESCAPED_SLASHES));
                return json_encode($response, JSON_UNESCAPED_SLASHES);
            }
            return json_encode(["success" => false, "message" => "Error adding demo user: " . $conn->error], JSON_UNESCAPED_SLASHES);
        }

    // POST - Add device to existing user or create new user
    } elseif ($method === 'POST') {
        if (empty($state_name)) return json_encode(["success" => false, "message" => "State name is required"], JSON_UNESCAPED_SLASHES);
        if (!preg_match('/^\d{10}$/', $mobile_number)) return json_encode(["success" => false, "message" => "Mobile number must be 10 digits"], JSON_UNESCAPED_SLASHES);

        $stmt = $conn->prepare("SELECT device_ids, state_id, default_pack_id, created_at, validity FROM demo_users WHERE mobile_number = ?");
        $stmt->bind_param("s", $mobile_number);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result->num_rows > 0) {
            $row = $result->fetch_assoc();
            $devices = !empty($row['device_ids']) ? explode(',', $row['device_ids']) : [];
            $devices = array_filter($devices, 'trim');

            if (!in_array($device_id, $devices)) {
                if (count($devices) >= $device_limit) {
                    return json_encode(["success" => false, "message" => "Device limit exceeded (max $device_limit devices)"], JSON_UNESCAPED_SLASHES);
                }
                $devices[] = $device_id;
                $new_device_ids = implode(',', $devices);

                $stmt = $conn->prepare("UPDATE demo_users SET device_ids = ? WHERE mobile_number = ?");
                $stmt->bind_param("ss", $new_device_ids, $mobile_number);
                if ($stmt->execute()) {
                    $stmt = $conn->prepare("SELECT package_name, file_name FROM default_packages WHERE id = ? LIMIT 1");
                    $stmt->bind_param("i", $row['default_pack_id']);
                    $stmt->execute();
                    $result = $stmt->get_result();
                    $package = $result->fetch_assoc();

                    $default_pack = $package["package_name"] ?? "Default Pack";
                    $file_name = $package["file_name"] ?? "";
                    error_log("POST - Retrieved file_name for existing user: $file_name");

                    if (empty($file_name) || !file_exists($file_name)) {
                        error_log("POST - No valid file_name for default_pack_id: {$row['default_pack_id']}");
                        return json_encode([
                            "success" => false,
                            "message" => "No valid M3U file available for this package"
                        ], JSON_UNESCAPED_SLASHES);
                    }

                    $channels = $file_name ? parseDemoM3UContent(fetchDemoFileContent($file_name)) : [];
                    $channels = assignDemoChannelIds($channels);

                    foreach ($channels as &$channel) {
                        unset($channel['channelLogoUrl']);
                        unset($channel['channelMainLogoUrl']);
                    }
                    unset($channel);

                    $validity_date = date('Y-m-d H:i:s', strtotime($row['created_at'] . " +{$row['validity']} hours"));
                    $response = [
                        "success" => true,
                        "message" => "Device added successfully",
                        "data" => [
                            "mobile_number" => $mobile_number,
                            "default_pack" => $default_pack,
                            "created_at" => $row['created_at'],
                            "validity_date" => $validity_date,
                            "device_ids" => $new_device_ids,
                            "package_list" => $channels
                        ]
                    ];
                    error_log("POST response: " . json_encode($response, JSON_UNESCAPED_SLASHES));
                    return json_encode($response, JSON_UNESCAPED_SLASHES);
                }
                return json_encode(["success" => false, "message" => "Error adding device: " . $conn->error], JSON_UNESCAPED_SLASHES);
            }
            return json_encode([
                "success" => false,
                "message" => "Device already exists for this user"
            ], JSON_UNESCAPED_SLASHES);
        } else {
            $stmt = $conn->prepare("SELECT id FROM states WHERE state_name = ? LIMIT 1");
            $stmt->bind_param("s", $state_name);
            $stmt->execute();
            $state = $stmt->get_result()->fetch_assoc();
            if (!$state) return json_encode(["success" => false, "message" => "Invalid state name"], JSON_UNESCAPED_SLASHES);
            $state_id = $state['id'];

            $stmt = $conn->prepare("SELECT id, package_name, file_name, validity FROM default_packages WHERE state_id = ? LIMIT 1");
            $stmt->bind_param("i", $state_id);
            $stmt->execute();
            $package = $stmt->get_result()->fetch_assoc();
            if (!$package) return json_encode(["success" => false, "message" => "No package found for state"], JSON_UNESCAPED_SLASHES);

            $default_pack_id = $package["id"];
            $default_pack = $package["package_name"] ?? "Default Pack";
            $default_validity = $package["validity"] ?? 24;
            $file_name = $package["file_name"] ?? "";
            $created_at = date('Y-m-d H:i:s');
            $device_ids = $device_id;
            $validity_date = date('Y-m-d H:i:s', strtotime("$created_at +{$default_validity} hours"));
            error_log("POST - Retrieved file_name for new user: $file_name");

            if (empty($file_name) || !file_exists($file_name)) {
                error_log("POST - No valid file_name for state_id: $state_id");
                return json_encode([
                    "success" => false,
                    "message" => "No valid M3U file available for this package"
                ], JSON_UNESCAPED_SLASHES);
            }

            $channels = $file_name ? parseDemoM3UContent(fetchDemoFileContent($file_name)) : [];
            $channels = assignDemoChannelIds($channels);

            foreach ($channels as &$channel) {
                unset($channel['channelLogoUrl']);
                unset($channel['channelMainLogoUrl']);
            }
            unset($channel);

            $response = [
                "success" => true,
                "message" => "Demo user added successfully",
                "data" => [
                    "mobile_number" => $mobile_number,
                    "default_pack" => $default_pack,
                    "default_validity" => $default_validity,
                    "created_at" => $created_at,
                    "validity_date" => $validity_date,
                    "device_ids" => $device_ids,
                    "package_list" => $channels
                ]
            ];

            $stmt = $conn->prepare("INSERT INTO demo_users (mobile_number, state_id, default_pack_id, default_pack, validity, file_name, created_at, device_ids) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
            $stmt->bind_param("sissssss", $mobile_number, $state_id, $default_pack_id, $default_pack, $default_validity, $file_name, $created_at, $device_ids);

            if ($stmt->execute()) {
                error_log("POST (new user) response: " . json_encode($response, JSON_UNESCAPED_SLASHES));
                return json_encode($response, JSON_UNESCAPED_SLASHES);
            }
            return json_encode(["success" => false, "message" => "Error adding demo user: " . $conn->error], JSON_UNESCAPED_SLASHES);
        }

    // PUT - Update existing user
    } elseif ($method === 'PUT') {
        if (empty($state_name)) return json_encode(["success" => false, "message" => "State name is required"], JSON_UNESCAPED_SLASHES);
        if (!preg_match('/^\d{10}$/', $mobile_number)) return json_encode(["success" => false, "message" => "Mobile number must be 10 digits"], JSON_UNESCAPED_SLASHES);

        // Check if user exists
        $stmt = $conn->prepare("SELECT id, device_ids FROM demo_users WHERE mobile_number = ?");
        $stmt->bind_param("s", $mobile_number);
        $stmt->execute();
        $result = $stmt->get_result();
        $user = $result->fetch_assoc();
        if (!$user) return json_encode(["success" => false, "message" => "User not found"], JSON_UNESCAPED_SLASHES);

        // Fetch state
        $stmt = $conn->prepare("SELECT id FROM states WHERE state_name = ? LIMIT 1");
        $stmt->bind_param("s", $state_name);
        $stmt->execute();
        $state = $stmt->get_result()->fetch_assoc();
        if (!$state) return json_encode(["success" => false, "message" => "Invalid state name"], JSON_UNESCAPED_SLASHES);
        $state_id = $state['id'];

        // Fetch package details
        $stmt = $conn->prepare("SELECT id, package_name, file_name, validity FROM default_packages WHERE state_id = ? LIMIT 1");
        $stmt->bind_param("i", $state_id);
        $stmt->execute();
        $package = $stmt->get_result()->fetch_assoc();
        if (!$package) return json_encode(["success" => false, "message" => "No package found for state"], JSON_UNESCAPED_SLASHES);

        $default_pack_id = $package["id"];
        $default_pack = $package["package_name"] ?? "Default Pack";
        $default_validity = isset($new_validity) && $new_validity > 0 ? $new_validity : ($package["validity"] ?? 24);
        $file_name = $package["file_name"] ?? "";
        // Reset created_at to start a new validity period
        $created_at = date('Y-m-d H:i:s');
        $validity_date = date('Y-m-d H:i:s', strtotime("$created_at +{$default_validity} hours"));
        error_log("PUT - Retrieved file_name for update: $file_name, validity: $default_validity, created_at: $created_at");

        if (empty($file_name) || !file_exists($file_name)) {
            error_log("PUT - No valid file_name for state_id: $state_id");
            return json_encode([
                "success" => false,
                "message" => "No valid M3U file available for this package"
            ], JSON_UNESCAPED_SLASHES);
        }

        // Update device_ids (already handled above, ensure consistency)
        $new_device_ids = $user['device_ids'] ? $user['device_ids'] : $device_id;

        // Update user
        $stmt = $conn->prepare(
            "UPDATE demo_users SET state_id = ?, default_pack_id = ?, default_pack = ?, validity = ?, file_name = ?, device_ids = ?, created_at = ? WHERE mobile_number = ?"
        );
        $stmt->bind_param(
            "isssssss",
            $state_id,
            $default_pack_id,
            $default_pack,
            $default_validity,
            $file_name,
            $new_device_ids,
            $created_at,
            $mobile_number
        );

        $channels = $file_name ? parseDemoM3UContent(fetchDemoFileContent($file_name)) : [];
        $channels = assignDemoChannelIds($channels);

        foreach ($channels as &$channel) {
            unset($channel['channelLogoUrl']);
            unset($channel['channelMainLogoUrl']);
        }
        unset($channel);

        $response = [
            "success" => true,
            "message" => "Demo user updated successfully",
            "data" => [
                "mobile_number" => $mobile_number,
                "default_pack" => $default_pack,
                "default_validity" => $default_validity,
                "created_at" => $created_at,
                "validity_date" => $validity_date,
                "device_ids" => $new_device_ids,
                "package_list" => $channels
            ]
        ];

        if ($stmt->execute()) {
            error_log("PUT response: " . json_encode($response, JSON_UNESCAPED_SLASHES));
            return json_encode($response, JSON_UNESCAPED_SLASHES);
        }
        return json_encode(["success" => false, "message" => "Error updating demo user: " . $conn->error], JSON_UNESCAPED_SLASHES);
    }

    return json_encode(["success" => false, "message" => "Invalid request method"], JSON_UNESCAPED_SLASHES);
}

// Separate DELETE endpoint
function deleteDemoUser($conn) {
    $json = file_get_contents("php://input");
    $data = json_decode($json, true);
    $mobile_number = isset($data['mobile_number']) ? trim($data['mobile_number']) : '';

    if (empty($mobile_number)) {
        return json_encode(["success" => false, "message" => "Mobile number is required"], JSON_UNESCAPED_SLASHES);
    }

    $stmt = $conn->prepare("DELETE FROM demo_users WHERE mobile_number = ?");
    $stmt->bind_param("s", $mobile_number);

    if ($stmt->execute()) {
        return json_encode(["success" => true, "message" => "Demo user deleted successfully"], JSON_UNESCAPED_SLASHES);
    }
    return json_encode(["success" => false, "message" => "Error deleting demo user: " . $conn->error], JSON_UNESCAPED_SLASHES);
}

// Direct routing based on HTTP method
$method = $_SERVER['REQUEST_METHOD'];
if ($method === 'DELETE') {
    echo deleteDemoUser($conn);
} else {
    echo manageDemoUser($conn);
}

if ($conn && $conn->ping()) {
    $conn->close();
}
ob_end_flush();
?>