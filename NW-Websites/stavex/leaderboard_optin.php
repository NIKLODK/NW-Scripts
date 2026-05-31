<?php
require_once __DIR__ . "/includes/auth.php";
require_once __DIR__ . "/includes/db.php";

if (!is_logged_in()) {
    header("Location: login.php");
    exit;
}

$user = discord_user();
$discordUserId = $user["id"] ?? null;
$discordUsername = $user["username"] ?? null;
$discordGlobalName = $user["global_name"] ?? null;

if ($discordUserId === null) {
    header("Location: donate.php");
    exit;
}

$optIn = ($_POST["opt_in"] ?? "no") === "yes";
$nickname = trim($_POST["nickname"] ?? "");

if ($optIn && $nickname === "") {
    header("Location: donate.php?status=success&error=nickname");
    exit;
}

$now = date("Y-m-d H:i:s");

$sql = "INSERT INTO leaderboard_optin (discord_user_id, nickname, opted_in, updated_at)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE nickname = VALUES(nickname), opted_in = VALUES(opted_in), updated_at = VALUES(updated_at)";

$displayName = $optIn ? $nickname : null;

db_execute($sql, [
    $discordUserId,
    $displayName,
    $optIn ? 1 : 0,
    $now,
]);

// Try to connect past donations to this Discord user if they used a name.
$lastDonationName = $_SESSION["last_donation_name"] ?? null;
$candidateNames = array_filter([$discordUsername, $discordGlobalName, $lastDonationName]);

if (!empty($candidateNames)) {
    $placeholders = implode(",", array_fill(0, count($candidateNames), "?"));
    $params = array_merge([$discordUserId], $candidateNames);
    $sql = "UPDATE donations
            SET discord_user_id = ?
            WHERE (discord_user_id IS NULL OR discord_user_id LIKE 'cus_%')
              AND discord_name IN ($placeholders)";
    db_execute($sql, $params);
}

header("Location: donate.php?status=success&saved=1");
exit;
