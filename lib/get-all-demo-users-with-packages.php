<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

require 'db.php';

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"]));
}

function getAllDemoUsersWithPackages($conn) {
    $result = $conn->query("SELECT du.id, du.mobile_number, du.reg_date, du.validity, du.default_pack, dp.package_name 
    FROM demo_users du 
    LEFT JOIN default_packages dp ON du.default_pack = dp.package_name 
    ORDER BY du.created_at DESC");
    $users = [];

    while ($row = $result->fetch_assoc()) {
        $users[] = $row;
    }

    echo json_encode(["success" => true, "users" => $users]);
}

getAllDemoUsersWithPackages($conn);
?>