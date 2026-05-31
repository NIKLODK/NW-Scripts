<?php
require_once __DIR__ . "/includes/db.php";
require_once __DIR__ . "/includes/discord_notifications.php";

function render_action_response(int $httpCode, string $title, string $message): void
{
    http_response_code($httpCode);
    $safeTitle = htmlspecialchars($title, ENT_QUOTES, "UTF-8");
    $safeMessage = nl2br(htmlspecialchars($message, ENT_QUOTES, "UTF-8"));
    echo "<!doctype html>";
    echo "<html lang=\"da\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">";
    echo "<title>" . $safeTitle . "</title>";
    echo "<style>body{font-family:Arial,sans-serif;background:#0f172a;color:#e2e8f0;margin:0;padding:32px}main{max-width:680px;margin:0 auto;background:#111827;border:1px solid #334155;border-radius:12px;padding:24px}h1{margin-top:0;font-size:24px}p{line-height:1.5;color:#cbd5e1}</style>";
    echo "</head><body><main><h1>" . $safeTitle . "</h1><p>" . $safeMessage . "</p></main></body></html>";
    exit;
}

$id = (int) ($_GET["id"] ?? 0);
$status = trim((string) ($_GET["status"] ?? ""));
$expires = (int) ($_GET["expires"] ?? 0);
$token = trim((string) ($_GET["token"] ?? ""));

if ($id <= 0 || !in_array($status, ["approved", "denied"], true) || $expires <= 0 || $token === "") {
    render_action_response(400, "Ugyldig handling", "Linket mangler data eller er ikke gyldigt.");
}

if (!verify_application_action_token($id, $status, $expires, $token)) {
    render_action_response(403, "Ugyldig handling", "Linket er udløbet eller signaturen matcher ikke.");
}

$applicationRows = db_fetch_all(
    "SELECT a.status, a.discord_user_id, a.applicant_name, a.type, a.staff_response, f.title AS form_title
     FROM applications a
     LEFT JOIN application_forms f ON f.id = a.form_id
     WHERE a.id = ?
     LIMIT 1",
    [$id]
);
$application = $applicationRows[0] ?? null;
if (!$application) {
    render_action_response(404, "Ikke fundet", "Ansøgningen findes ikke.");
}

$currentStatus = (string) ($application["status"] ?? "pending");
if ($currentStatus === $status) {
    render_action_response(200, "Allerede opdateret", "Ansøgningen har allerede status: " . application_status_text($status) . ".");
}

$now = date("Y-m-d H:i:s");
$updated = db_execute(
    "UPDATE applications
     SET status = ?, updated_at = ?, answered_at = IF(? IN ('approved', 'denied'), ?, NULL), notified = 0
     WHERE id = ?",
    [$status, $now, $status, $now, $id]
);
if (!$updated) {
    render_action_response(500, "Fejl", "Status kunne ikke opdateres i databasen.");
}

$discordUserId = trim((string) ($application["discord_user_id"] ?? ""));
$applicantName = trim((string) ($application["applicant_name"] ?? "Ansøger"));
$applicationTitle = trim((string) ($application["form_title"] ?? ""));
if ($applicationTitle === "") {
    $applicationTitle = trim((string) ($application["type"] ?? "ansøgning"));
}

$staffResponse = trim((string) ($application["staff_response"] ?? ""));
$dmMessage = build_application_status_dm_message($applicantName, $applicationTitle, $status, $staffResponse, $id);
discord_send_dm($discordUserId, $dmMessage);

$statusLabel = application_status_text($status);
render_action_response(200, "Status opdateret", "Ansøgning #" . $id . " er nu " . $statusLabel . ".");
