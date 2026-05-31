<?php
require_once __DIR__ . "/includes/auth.php";
require_once __DIR__ . "/includes/db.php";
require_once __DIR__ . "/includes/application_lifecycle.php";

if (!is_logged_in()) {
    header("Location: login.php");
    exit;
}

$id = (int) ($_POST["id"] ?? 0);
if ($id <= 0) {
    header("Location: applications.php?delete_error=1");
    exit;
}

$user = discord_user();
$currentDiscordId = trim((string) ($user["id"] ?? ""));
$isPrivileged = is_staff() || is_admin();

$rows = db_fetch_all(
    "SELECT id, discord_user_id, status FROM applications WHERE id = ? LIMIT 1",
    [$id]
);
$application = $rows[0] ?? null;
if (!$application) {
    $fallback = $isPrivileged ? "staff_panel.php?tab=answered&deleted=0" : "applications.php?delete_error=1";
    header("Location: " . $fallback);
    exit;
}

$ownerDiscordId = trim((string) ($application["discord_user_id"] ?? ""));
$status = (string) ($application["status"] ?? "pending");

if (!$isPrivileged) {
    if ($currentDiscordId === "" || $ownerDiscordId !== $currentDiscordId || $status === "pending") {
        http_response_code(403);
        echo "Ingen adgang";
        exit;
    }
}

$reason = $isPrivileged ? "manual_staff" : "manual_user";
$deletedBy = $currentDiscordId !== "" ? $currentDiscordId : null;
$ok = application_archive_and_delete($id, $reason, $deletedBy);

if ($isPrivileged) {
    header("Location: staff_panel.php?tab=answered&deleted=" . ($ok ? "1" : "0"));
    exit;
}

header("Location: applications.php?" . ($ok ? "deleted=1" : "delete_error=1"));
exit;
