<?php
ob_start(); // Start output buffering to catch any unintended output

// Enable error reporting for debugging
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Accept, User-Agent");
header("Content-Type: application/json");

// Handle OPTIONS requests (CORS preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    header("HTTP/1.1 204 No Content");
    exit;
}

require 'db.php';

if (!$conn) {
    ob_end_clean(); // Clear any output
    die(json_encode(["success" => false, "message" => "Database connection failed"]));
}

function getFileUrl($fileName) {
    if (empty($fileName)) {
        error_log("File name is empty");
        return null;
    }
    return "https://sms.mydreamplaytv.com/upload-file.php?file_name=" . urlencode(basename($fileName));
}

function getPartners($conn) {
    $result = $conn->query("SELECT id,  partner_name, partner_code, state_id, logos, splash_screen, board, registration_date FROM partners");
    if ($result === false) {
        ob_end_clean();
        echo json_encode(["success" => false, "message" => "Query failed: " . $conn->error]);
        return;
    }
    $partners = [];
    while ($row = $result->fetch_assoc()) {
        $row['logos_url'] = getFileUrl($row['logos']);
        $row['splash_screen_url'] = getFileUrl($row['splash_screen']);
        $row['board_url'] = getFileUrl($row['board']);
        $partners[] = $row;
    }
    ob_end_clean(); // Clear any output before sending JSON
    echo json_encode(["success" => true, "partners" => $partners], JSON_THROW_ON_ERROR);
}

getPartners($conn);