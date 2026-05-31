<?php
require_once __DIR__ . "/includes/auth.php";
require_once __DIR__ . "/includes/db.php";

if (!is_staff() && !is_admin()) {
    http_response_code(403);
    echo "Ingen adgang";
    exit;
}

$name = trim($_POST["name"] ?? "");
$sortOrder = (int) ($_POST["sort_order"] ?? 0);
$id = $_POST["id"] ?? null;

if ($name === "") {
    header("Location: staff_panel.php");
    exit;
}

$now = date("Y-m-d H:i:s");

if ($id) {
    db_execute(
        "UPDATE law_categories SET name = ?, sort_order = ?, updated_at = ? WHERE id = ?",
        [$name, $sortOrder, $now, $id]
    );
} else {
    db_execute(
        "INSERT INTO law_categories (name, sort_order, updated_at) VALUES (?, ?, ?)",
        [$name, $sortOrder, $now]
    );
}

header("Location: staff_panel.php");
exit;