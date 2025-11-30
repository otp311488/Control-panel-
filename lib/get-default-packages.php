<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

require 'db.php';

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"]));
}

function getDefaultPackages($conn) {
    $result = $conn->query("SELECT id, package_name, state_id, file_name FROM default_packages");
    if (!$result) {
        echo json_encode(["success" => false, "message" => "Error fetching packages: " . $conn->error]);
        return;
    }

    $packages = [];
    while ($row = $result->fetch_assoc()) {
        $packages[] = $row;
    }

    echo json_encode(["success" => true, "packages" => $packages]);
}

getDefaultPackages($conn);
?>