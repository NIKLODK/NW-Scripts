<?php
require_once __DIR__ . "/includes/auth.php";
require_once __DIR__ . "/includes/db.php";
require_once __DIR__ . "/includes/discord_notifications.php";

if (!is_logged_in()) {
    header("Location: login.php");
    exit;
}

$formId = (int) ($_POST["form_id"] ?? 0);
$contentParts = $_POST["content"] ?? [];
$user = discord_user();
$userId = $user["id"] ?? null;
$displayName = $user["username"] ?? "Ukendt";

$hasWebhookColumn = !empty(db_fetch_all("SHOW COLUMNS FROM application_forms LIKE 'webhook_url'"));
$formColumns = "id, type, title, visibility, questions";
if ($hasWebhookColumn) {
    $formColumns .= ", webhook_url";
}
$formRows = db_fetch_all("SELECT {$formColumns} FROM application_forms WHERE id = ? LIMIT 1", [$formId]);
$form = $formRows[0] ?? null;
if (!$form) {
    header("Location: applications.php");
    exit;
}

$requiresWhitelist = $form["visibility"] === "whitelist";
if ($requiresWhitelist && !(is_whitelisted() || is_staff() || is_admin())) {
    http_response_code(403);
    echo "Ingen adgang";
    exit;
}

$answers = array_map("trim", is_array($contentParts) ? $contentParts : []);
$answers = array_filter($answers, fn($v) => $v !== "");
if (empty($answers)) {
    header("Location: apply.php?form_id=" . $formId);
    exit;
}

$content = json_encode([
    "questions" => $form["questions"],
    "answers" => array_values($answers),
], JSON_UNESCAPED_UNICODE);

$now = date("Y-m-d H:i:s");

db_execute(
    "INSERT INTO applications (type, applicant_name, discord_user_id, form_id, content, status, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, 'pending', ?, ?)",
    [$form["type"], $displayName, $userId, $formId, $content, $now, $now]
);

$insertedRows = db_fetch_all("SELECT LAST_INSERT_ID() AS id");
$applicationId = (int) ($insertedRows[0]["id"] ?? 0);

$questionItems = preg_split("/\r\n|\r|\n/", (string) ($form["questions"] ?? ""));
$questionItems = array_values(array_filter(array_map("trim", $questionItems), fn($q) => $q !== ""));
$answerItems = array_values($answers);
$questionAnswerItems = [];
foreach ($answerItems as $index => $answer) {
    $questionAnswerItems[] = [
        "question" => $questionItems[$index] ?? ("Svar " . ($index + 1)),
        "answer" => $answer,
    ];
}

$webhookUrl = $hasWebhookColumn ? trim((string) ($form["webhook_url"] ?? "")) : "";
if ($webhookUrl !== "") {
    send_json_webhook($webhookUrl, [
        "event" => "application.created",
        "application" => [
            "id" => $applicationId,
            "status" => "pending",
            "type" => $form["type"],
            "form_id" => $formId,
            "form_title" => $form["title"] ?? null,
            "applicant_name" => $displayName,
            "discord_user_id" => $userId,
            "content" => $content,
            "questions" => $questionItems,
            "answers" => $answerItems,
            "question_answers" => $questionAnswerItems,
            "created_at" => $now,
        ],
    ]);
}

send_discord_new_application_notification([
    "id" => $applicationId,
    "type" => $form["type"] ?? "general",
    "form_id" => $formId,
    "form_title" => $form["title"] ?? "",
    "applicant_name" => $displayName,
    "discord_user_id" => $userId,
    "question_answers" => $questionAnswerItems,
    "created_at" => $now,
]);

header("Location: applications.php?created=1");
exit;
