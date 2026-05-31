<?php
require_once __DIR__ . "/includes/auth.php";
require_once __DIR__ . "/includes/db.php";

if (!is_staff() && !is_admin()) {
    http_response_code(403);
    echo "Ingen adgang";
    exit;
}

$id = $_POST["id"] ?? null;
$categoryId = filter_var($id, FILTER_VALIDATE_INT);

if (!$categoryId) {
    header("Location: staff_panel.php");
    exit;
}

db_execute("UPDATE rules SET category_id = NULL WHERE category_id = ?", [$categoryId]);
db_execute("DELETE FROM rule_categories WHERE id = ?", [$categoryId]);

header("Location: staff_panel.php");
exit;