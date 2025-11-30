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

function checkPartnerLogos($conn) {
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
        // Retrieve logos
        $stmt = $conn->prepare("SELECT logos FROM partners WHERE partner_code = ? LIMIT 1");
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
            "message" => "Logos retrieved successfully",
            "logos" => getFileUrl($partner["logos"])
        ], JSON_UNESCAPED_SLASHES);
    } elseif ($method === 'POST') {
        // Add logos
        $logos = isset($_GET['logos']) ? trim($_GET['logos']) : (isset($data['logos']) ? trim($data['logos']) : '');

        if (empty($logos)) {
            return json_encode(["success" => false, "message" => "Logos URL is required"], JSON_UNESCAPED_SLASHES);
        }

        $stmt = $conn->prepare("INSERT INTO partners (partner_code, logos) VALUES (?, ?) ON DUPLICATE KEY UPDATE logos = ?");
        if (!$stmt) {
            return json_encode(["success" => false, "message" => "Database insert query preparation failed"], JSON_UNESCAPED_SLASHES);
        }
        $stmt->bind_param("sss", $partner_code, $logos, $logos);

        if ($stmt->execute()) {
            // Fetch the updated logos (same as GET)
            $stmt = $conn->prepare("SELECT logos FROM partners WHERE partner_code = ? LIMIT 1");
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
                "message" => "Logos added successfully",
                "logos" => getFileUrl($partner["logos"])
            ], JSON_UNESCAPED_SLASHES);
        } else {
            return json_encode(["success" => false, "message" => "Error adding logos: " . $conn->error], JSON_UNESCAPED_SLASHES);
        }
    } elseif ($method === 'PUT') {
        // Update logos
        $logos = isset($_GET['logos']) ? trim($_GET['logos']) : (isset($data['logos']) ? trim($data['logos']) : '');

        if (empty($logos)) {
            return json_encode(["success" => false, "message" => "Logos URL is required"], JSON_UNESCAPED_SLASHES);
        }

        $stmt = $conn->prepare("UPDATE partners SET logos = ? WHERE partner_code = ?");
        if (!$stmt) {
            return json_encode(["success" => false, "message" => "Database update query preparation failed"], JSON_UNESCAPED_SLASHES);
        }
        $stmt->bind_param("ss", $logos, $partner_code);

        if ($stmt->execute()) {
            return json_encode(["success" => true, "message" => "Logos updated successfully"], JSON_UNESCAPED_SLASHES);
        } else {
            return json_encode(["success" => false, "message" => "Error updating logos: " . $conn->error], JSON_UNESCAPED_SLASHES);
        }
    } elseif ($method === 'DELETE') {
        // Delete logos (set to NULL)
        $stmt = $conn->prepare("UPDATE partners SET logos = NULL WHERE partner_code = ?");
        if (!$stmt) {
            return json_encode(["success" => false, "message" => "Database delete query preparation failed"], JSON_UNESCAPED_SLASHES);
        }
        $stmt->bind_param("s", $partner_code);

        if ($stmt->execute()) {
            return json_encode(["success" => true, "message" => "Logos deleted successfully"], JSON_UNESCAPED_SLASHES);
        } else {
            return json_encode(["success" => false, "message" => "Error deleting logos: " . $conn->error], JSON_UNESCAPED_SLASHES);
        }
    }

    return json_encode(["success" => false, "message" => "Invalid request method"], JSON_UNESCAPED_SLASHES);
}

echo checkPartnerLogos($conn);

if ($conn && $conn->ping()) {
    $conn->close();
}
?>