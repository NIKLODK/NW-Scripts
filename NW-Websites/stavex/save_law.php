<?php
require_once __DIR__ . "/includes/auth.php";
require_once __DIR__ . "/includes/db.php";

if (!is_staff() && !is_admin()) {
    http_response_code(403);
    echo "Ingen adgang";
    exit;
}

$title = trim($_POST["title"] ?? "");
$body = trim($_POST["body"] ?? "");
$id = $_POST["id"] ?? null;
$categoryInput = $_POST["category_id"] ?? "";
$categoryId = filter_var($categoryInput, FILTER_VALIDATE_INT);
$categoryParam = $categoryId ? (string) $categoryId : "";

if ($title === "" || $body === "") {
    header("Location: staff_panel.php");
    exit;
}

$now = date("Y-m-d H:i:s");

if ($id) {
    db_execute(
        "UPDATE laws SET category_id = NULLIF(?, ''), title = ?, body = ?, updated_at = ? WHERE id = ?",
        [$categoryParam, $title, $body, $now, $id]
    );
} else {
    db_execute(
        "INSERT INTO laws (category_id, title, body, updated_at) VALUES (NULLIF(?, ''), ?, ?, ?)",
        [$categoryParam, $title, $body, $now]
    );
}

header("Location: staff_panel.php");
exit;