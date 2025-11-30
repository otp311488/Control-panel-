<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

require 'db.php';

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"]));
}

function getPartnerPackages($conn) {
    $result = $conn->query("SELECT id, package_name, partner_id, partner_code, file_name FROM partner_packages ORDER BY created_at DESC");
    $packages = [];

    while ($row = $result->fetch_assoc()) {
        $packages[] = $row;
    }

    echo json_encode(["success" => true, "packages" => $packages]);
}

getPartnerPackages($conn);
?>