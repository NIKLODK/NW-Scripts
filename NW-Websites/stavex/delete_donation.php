<?php
require_once __DIR__ . "/includes/auth.php";
require_once __DIR__ . "/includes/db.php";

if (!is_admin()) {
    http_response_code(403);
    echo "Ingen adgang";
    exit;
}

$discordUserId = trim($_POST["discord_user_id"] ?? "");

if ($discordUserId === "") {
    header("Location: staff_panel.php");
    exit;
}

// Delete all donations and leaderboard settings for this user
db_execute("DELETE FROM donations WHERE discord_user_id = ?", [$discordUserId]);
db_execute("DELETE FROM leaderboard_optin WHERE discord_user_id = ?", [$discordUserId]);

header("Location: staff_panel.php");
exit;
