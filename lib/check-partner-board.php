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

function checkPartnerBoard($conn) {
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
        // Retrieve board
        $stmt = $conn->prepare("SELECT board FROM partners WHERE partner_code = ? LIMIT 1");
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
            "message" => "Board retrieved successfully",
            "board" => getFileUrl($partner["board"])
        ], JSON_UNESCAPED_SLASHES);
    } elseif ($method === 'POST') {
        // Add board
        $board = isset($_GET['board']) ? trim($_GET['board']) : (isset($data['board']) ? trim($data['board']) : '');

        if (empty($board)) {
            return json_encode(["success" => false, "message" => "Board URL is required"], JSON_UNESCAPED_SLASHES);
        }

        $stmt = $conn->prepare("INSERT INTO partners (partner_code, board) VALUES (?, ?) ON DUPLICATE KEY UPDATE board = ?");
        if (!$stmt) {
            return json_encode(["success" => false, "message" => "Database insert query preparation failed"], JSON_UNESCAPED_SLASHES);
        }
        $stmt->bind_param("sss", $partner_code, $board, $board);

        if ($stmt->execute()) {
            // Fetch the updated board (same as GET)
            $stmt = $conn->prepare("SELECT board FROM partners WHERE partner_code = ? LIMIT 1");
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
                "message" => "Board added successfully",
                "board" => getFileUrl($partner["board"])
            ], JSON_UNESCAPED_SLASHES);
        } else {
            return json_encode(["success" => false, "message" => "Error adding board: " . $conn->error], JSON_UNESCAPED_SLASHES);
        }
    } elseif ($method === 'PUT') {
        // Update board
        $board = isset($_GET['board']) ? trim($_GET['board']) : (isset($data['board']) ? trim($data['board']) : '');

        if (empty($board)) {
            return json_encode(["success" => false, "message" => "Board URL is required"], JSON_UNESCAPED_SLASHES);
        }

        $stmt = $conn->prepare("UPDATE partners SET board = ? WHERE partner_code = ?");
        if (!$stmt) {
            return json_encode(["success" => false, "message" => "Database update query preparation failed"], JSON_UNESCAPED_SLASHES);
        }
        $stmt->bind_param("ss", $board, $partner_code);

        if ($stmt->execute()) {
            return json_encode(["success" => true, "message" => "Board updated successfully"], JSON_UNESCAPED_SLASHES);
        } else {
            return json_encode(["success" => false, "message" => "Error updating board: " . $conn->error], JSON_UNESCAPED_SLASHES);
        }
    } elseif ($method === 'DELETE') {
        // Delete board (set to NULL)
        $stmt = $conn->prepare("UPDATE partners SET board = NULL WHERE partner_code = ?");
        if (!$stmt) {
            return json_encode(["success" => false, "message" => "Database delete query preparation failed"], JSON_UNESCAPED_SLASHES);
        }
        $stmt->bind_param("s", $partner_code);

        if ($stmt->execute()) {
            return json_encode(["success" => true, "message" => "Board deleted successfully"], JSON_UNESCAPED_SLASHES);
        } else {
            return json_encode(["success" => false, "message" => "Error deleting board: " . $conn->error], JSON_UNESCAPED_SLASHES);
        }
    }

    return json_encode(["success" => false, "message" => "Invalid request method"], JSON_UNESCAPED_SLASHES);
}

echo checkPartnerBoard($conn);

if ($conn && $conn->ping()) {
    $conn->close();
}
?>