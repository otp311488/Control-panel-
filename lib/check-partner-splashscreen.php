<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

require 'db.php';
require 'file_handler.php';

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"], JSON_UNESCAPED_SLASHES));
}

function checkPartnerSplashScreen($conn) {
    $method = $_SERVER['REQUEST_METHOD'];

    if ($method === 'GET' || $method === 'POST' || $method === 'PUT') {
        $partner_code = isset($_GET['code']) ? trim($_GET['code']) : '';
    } else {
        $json = file_get_contents("php://input");
        $data = json_decode($json, true);
        $partner_code = isset($data['code']) ? trim($data['code']) : '';
    }

    if (empty($partner_code)) {
        return json_encode(["success" => false, "message" => "Partner code is required"], JSON_UNESCAPED_SLASHES);
    }

    if ($method === 'GET') {
        // Retrieve splash screen
        $stmt = $conn->prepare("SELECT splash_screen FROM partners WHERE partner_code = ? LIMIT 1");
        if (!$stmt) {
            return json_encode(["success" => false, "message" => "Database query preparation failed"], JSON_UNESCAPED_SLASHES);
        }
        $stmt->bind_param("s", $partner_code);
        $stmt->execute();
        $partner_result = $stmt->get_result();
        $partner = $partner_result->fetch_assoc();

        if (!$partner) {
            return json_encode(["success" => false, "message" => "Partner does not exist"], JSON_UNESCAPED_SLASHES);
        }

        return json_encode([
            "success" => true,
            "message" => "Splash screen retrieved successfully",
            "splash_screen" => getFileUrl($partner["splash_screen"])
        ], JSON_UNESCAPED_SLASHES);
    } elseif ($method === 'POST') {
        // Add a new partner with splash screen
        $splash_screen = isset($_GET['splash_screen']) ? trim($_GET['splash_screen']) : (isset($data['splash_screen']) ? trim($data['splash_screen']) : '');

        if (empty($splash_screen)) {
            return json_encode(["success" => false, "message" => "Splash screen URL is required"], JSON_UNESCAPED_SLASHES);
        }

        $stmt = $conn->prepare("INSERT INTO partners (partner_code, splash_screen) VALUES (?, ?) ON DUPLICATE KEY UPDATE splash_screen = ?");
        if (!$stmt) {
            return json_encode(["success" => false, "message" => "Database insert query preparation failed"], JSON_UNESCAPED_SLASHES);
        }
        $stmt->bind_param("sss", $partner_code, $splash_screen, $splash_screen);

        if ($stmt->execute()) {
            // Fetch the updated splash screen (same as GET)
            $stmt = $conn->prepare("SELECT splash_screen FROM partners WHERE partner_code = ? LIMIT 1");
            if (!$stmt) {
                return json_encode(["success" => false, "message" => "Database query preparation failed after insert"], JSON_UNESCAPED_SLASHES);
            }
            $stmt->bind_param("s", $partner_code);
            $stmt->execute();
            $partner_result = $stmt->get_result();
            $partner = $partner_result->fetch_assoc();

            if (!$partner) {
                return json_encode(["success" => false, "message" => "Partner does not exist after insert"], JSON_UNESCAPED_SLASHES);
            }

            return json_encode([
                "success" => true,
                "message" => "Splash screen added successfully",
                "splash_screen" => getFileUrl($partner["splash_screen"])
            ], JSON_UNESCAPED_SLASHES);
        } else {
            return json_encode(["success" => false, "message" => "Error adding splash screen: " . $conn->error], JSON_UNESCAPED_SLASHES);
        }
    } elseif ($method === 'PUT') {
        // Update splash screen
        $splash_screen = isset($_GET['splash_screen']) ? trim($_GET['splash_screen']) : (isset($data['splash_screen']) ? trim($data['splash_screen']) : '');

        if (empty($splash_screen)) {
            return json_encode(["success" => false, "message" => "Splash screen URL is required"], JSON_UNESCAPED_SLASHES);
        }

        $stmt = $conn->prepare("UPDATE partners SET splash_screen = ? WHERE partner_code = ?");
        if (!$stmt) {
            return json_encode(["success" => false, "message" => "Database update query preparation failed"], JSON_UNESCAPED_SLASHES);
        }
        $stmt->bind_param("ss", $splash_screen, $partner_code);

        if ($stmt->execute()) {
            return json_encode(["success" => true, "message" => "Splash screen updated successfully"], JSON_UNESCAPED_SLASHES);
        } else {
            return json_encode(["success" => false, "message" => "Error updating splash screen: " . $conn->error], JSON_UNESCAPED_SLASHES);
        }
    } elseif ($method === 'DELETE') {
        // Delete splash screen (set to NULL)
        $stmt = $conn->prepare("UPDATE partners SET splash_screen = NULL WHERE partner_code = ?");
        if (!$stmt) {
            return json_encode(["success" => false, "message" => "Database delete query preparation failed"], JSON_UNESCAPED_SLASHES);
        }
        $stmt->bind_param("s", $partner_code);

        if ($stmt->execute()) {
            return json_encode(["success" => true, "message" => "Splash screen deleted successfully"], JSON_UNESCAPED_SLASHES);
        } else {
            return json_encode(["success" => false, "message" => "Error deleting splash screen: " . $conn->error], JSON_UNESCAPED_SLASHES);
        }
    }

    return json_encode(["success" => false, "message" => "Invalid request method"], JSON_UNESCAPED_SLASHES);
}

echo checkPartnerSplashScreen($conn);

if ($conn && $conn->ping()) {
    $conn->close();
}
?>