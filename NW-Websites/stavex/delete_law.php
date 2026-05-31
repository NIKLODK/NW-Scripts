<?php
require_once __DIR__ . "/includes/auth.php";
require_once __DIR__ . "/includes/db.php";

if (!is_staff() && !is_admin()) {
    http_response_code(403);
    echo "Ingen adgang";
    exit;
}

$id = $_POST["id"] ?? null;
$lawId = filter_var($id, FILTER_VALIDATE_INT);

if (!$lawId) {
    header("Location: staff_panel.php");
    exit;
}

db_execute("DELETE FROM laws WHERE id = ?", [$lawId]);

header("Location: staff_panel.php");
exit;