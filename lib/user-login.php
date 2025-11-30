<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

require 'db.php'; // Ensure this file correctly sets up $conn

if (!$conn) {
    die(json_encode(["success" => false, "message" => "Database connection failed"]));
}

function userLogin($conn) {
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);

    if (empty($data['username']) || empty($data['password'])) {
        echo json_encode(["success" => false, "message" => "Username and password are required"]);
        return;
    }

    $username = trim($data['username']);
    $password = trim($data['password']);

    $stmt = $conn->prepare("SELECT username, password FROM users WHERE username = ?");
    $stmt->bind_param("s", $username);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result->fetch_assoc();

    if (!$user || strcmp($password, $user['password']) !== 0) {
        echo json_encode(["success" => false, "message" => "Invalid username or password"]);
        return;
    }

    echo json_encode(["success" => true, "message" => "Login successful"]);
}

userLogin($conn);
?>