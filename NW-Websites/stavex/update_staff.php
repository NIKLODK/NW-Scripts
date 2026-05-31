<?php
require_once __DIR__ . "/includes/auth.php";
require_once __DIR__ . "/includes/db.php";

if (!is_staff() && !is_admin()) {
    http_response_code(403);
    echo "Ingen adgang";
    exit;
}

$discordId = trim($_POST["discord_user_id"] ?? "");
$title = trim($_POST["title"] ?? "");
$sortOrder = (int) ($_POST["sort_order"] ?? 0);

if ($discordId === "") {
    header("Location: staff_panel.php");
    exit;
}

$now = gmdate("Y-m-d H:i:s");
db_execute(
    "UPDATE staff_members SET title = ?, sort_order = ?, updated_at = ? WHERE discord_user_id = ?",
    [$title, (string) $sortOrder, $now, $discordId]
);

header("Location: staff_panel.php");
exit;
