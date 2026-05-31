<?php
require_once __DIR__ . "/includes/auth.php";
require_once __DIR__ . "/includes/db.php";

if (!is_staff() && !is_admin()) {
    http_response_code(403);
    echo "Ingen adgang";
    exit;
}

$discordUserId = trim($_POST["discord_user_id"] ?? "");
$optIn = ($_POST["opt_in"] ?? "no") === "yes";
$nickname = trim($_POST["nickname"] ?? "");

if ($discordUserId === "") {
    header("Location: staff_panel.php");
    exit;
}

if ($optIn && $nickname === "") {
    $nickname = "Guld";
}

$now = date("Y-m-d H:i:s");

$dbNick = $optIn ? $nickname : null;

$sql = "INSERT INTO leaderboard_optin (discord_user_id, nickname, opted_in, updated_at)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE nickname = VALUES(nickname), opted_in = VALUES(opted_in), updated_at = VALUES(updated_at)";

db_execute($sql, [$discordUserId, $dbNick, $optIn ? 1 : 0, $now]);

header("Location: staff_panel.php");
exit;
