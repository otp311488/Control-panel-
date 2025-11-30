<?php
function managePartnerDevice($conn, $partner_code, $device_id, $method = 'GET') {
    if (!$conn) {
        return ["success" => false, "message" => "Database connection failed"];
    }

    if (empty($device_id) && $method !== 'DELETE') {
        return ["success" => false, "message" => "Device ID is required"];
    }

    // Check existing devices for this partner
    $stmt = $conn->prepare("SELECT device_id FROM partner_devices WHERE partner_code = ?");
    if (!$stmt) {
        return ["success" => false, "message" => "Device query preparation failed"];
    }
    $stmt->bind_param("s", $partner_code);
    $stmt->execute();
    $result = $stmt->get_result();

    $devices = [];
    while ($row = $result->fetch_assoc()) {
        $devices[] = $row['device_id'];
    }

    if ($method === 'GET') {
        return ["success" => true, "message" => "Devices retrieved successfully", "devices" => $devices];
    } elseif ($method === 'POST') {
        // If the device_id is already in the list, allow it (edit case)
        if (in_array($device_id, $devices)) {
            return ["success" => true, "message" => "Device already registered"];
        }

        // Check if the partner has reached the device limit (2 devices)
        if (count($devices) >= 2) {
            return ["success" => false, "message" => "Device limit reached (max 2 devices per partner)"];
        }

        // Add the new device
        $created_at = date('Y-m-d H:i:s');
        $stmt = $conn->prepare("INSERT INTO partner_devices (partner_code, device_id, created_at) VALUES (?, ?, ?)");
        if (!$stmt) {
            return ["success" => false, "message" => "Device insert query preparation failed"];
        }
        $stmt->bind_param("sss", $partner_code, $device_id, $created_at);

        if ($stmt->execute()) {
            return ["success" => true, "message" => "Device added successfully"];
        } else {
            return ["success" => false, "message" => "Error adding device: " . $conn->error];
        }
    } elseif ($method === 'PUT') {
        // Update device (replace an existing device with a new one)
        if (count($devices) == 0) {
            return ["success" => false, "message" => "No devices to update"];
        }
        $old_device_id = $devices[0]; // Replace the first device
        $stmt = $conn->prepare("UPDATE partner_devices SET device_id = ?, created_at = ? WHERE partner_code = ? AND device_id = ?");
        if (!$stmt) {
            return ["success" => false, "message" => "Device update query preparation failed"];
        }
        $created_at = date('Y-m-d H:i:s');
        $stmt->bind_param("ssss", $device_id, $created_at, $partner_code, $old_device_id);

        if ($stmt->execute()) {
            return ["success" => true, "message" => "Device updated successfully"];
        } else {
            return ["success" => false, "message" => "Error updating device: " . $conn->error];
        }
    } elseif ($method === 'DELETE') {
        // Delete a specific device
        $stmt = $conn->prepare("DELETE FROM partner_devices WHERE partner_code = ? AND device_id = ?");
        if (!$stmt) {
            return ["success" => false, "message" => "Device delete query preparation failed"];
        }
        $stmt->bind_param("ss", $partner_code, $device_id);

        if ($stmt->execute()) {
            return ["success" => true, "message" => "Device deleted successfully"];
        } else {
            return ["success" => false, "message" => "Error deleting device: " . $conn->error];
        }
    }

    return ["success" => false, "message" => "Invalid method"];
}
?>