<?php
require_once __DIR__ . "/includes/auth.php";
require_once __DIR__ . "/includes/staff.php";

if (!is_staff() && !is_admin()) {
    http_response_code(403);
    echo "Ingen adgang";
    exit;
}

$force = isset($_POST["force"]) && $_POST["force"] === "1";
$result = staff_sync_members($force);
$status = !empty($result["ok"]) ? "ok" : "fail";
$query = "staff_sync=" . $status;
if (!empty($result["error"])) {
    $query .= "&error=" . urlencode($result["error"]);
}

header("Location: staff_panel.php?" . $query);
exit;
