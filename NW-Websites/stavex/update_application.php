<?php
require_once __DIR__ . "/includes/auth.php";
require_once __DIR__ . "/includes/db.php";
require_once __DIR__ . "/includes/discord_notifications.php";

if (!is_staff() && !is_admin()) {
    http_response_code(403);
    echo "Ingen adgang";
    exit;
}

$id = (int) ($_POST["id"] ?? 0);
$status = $_POST["status"] ?? "pending";
$content = trim($_POST["content"] ?? "");
$staffResponse = trim($_POST["staff_response"] ?? "");
$allowed = ["pending", "approved", "denied"];

if ($id <= 0 || !in_array($status, $allowed, true)) {
    header("Location: staff_panel.php");
    exit;
}

$applicationRows = db_fetch_all(
    "SELECT a.status, a.discord_user_id, a.applicant_name, a.type, f.title AS form_title
     FROM applications a
     LEFT JOIN application_forms f ON f.id = a.form_id
     WHERE a.id = ?
     LIMIT 1",
    [$id]
);
$application = $applicationRows[0] ?? null;
if (!$application) {
    header("Location: staff_panel.php");
    exit;
}
$previousStatus = (string) ($application["status"] ?? "pending");
$now = date("Y-m-d H:i:s");

db_execute(
    "UPDATE applications
     SET status = ?, content = ?, staff_response = ?, updated_at = ?,
         answered_at = IF(? IN ('approved', 'denied'), ?, NULL), notified = 0
     WHERE id = ?",
    [$status, $content, $staffResponse, $now, $status, $now, $id]
);

if (
    in_array($status, ["approved", "denied"], true)
    && $previousStatus !== $status
) {
    $discordUserId = trim((string) ($application["discord_user_id"] ?? ""));
    $applicantName = trim((string) ($application["applicant_name"] ?? "Ansøger"));
    $applicationTitle = trim((string) ($application["form_title"] ?? ""));
    if ($applicationTitle === "") {
        $applicationTitle = trim((string) ($application["type"] ?? "ansøgning"));
    }

    $message = build_application_status_dm_message($applicantName, $applicationTitle, $status, $staffResponse, $id);
    discord_send_dm($discordUserId, $message);
}

header("Location: staff_panel.php");
exit;
