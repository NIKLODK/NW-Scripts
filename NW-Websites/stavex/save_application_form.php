<?php
require_once __DIR__ . "/includes/auth.php";
require_once __DIR__ . "/includes/db.php";

if (!is_staff() && !is_admin()) {
    http_response_code(403);
    echo "Ingen adgang";
    exit;
}

$id = (int) ($_POST["id"] ?? 0);
$title = trim($_POST["title"] ?? "");
$description = trim($_POST["description"] ?? "");
$rawQuestions = $_POST["questions"] ?? [];
$type = trim($_POST["type"] ?? "general");
$visibility = trim($_POST["visibility"] ?? "public");
$webhookUrl = trim($_POST["webhook_url"] ?? "");
$hasWebhookColumn = !empty(db_fetch_all("SHOW COLUMNS FROM application_forms LIKE 'webhook_url'"));

$questionItems = [];
if (is_array($rawQuestions)) {
    $questionItems = array_map("trim", $rawQuestions);
} else {
    $questionItems = preg_split("/\r\n|\r|\n/", trim((string) $rawQuestions));
}
$questionItems = array_values(array_filter($questionItems, fn($q) => $q !== ""));
$questions = implode("\n", $questionItems);

if ($webhookUrl !== "") {
    $isUrlValid = filter_var($webhookUrl, FILTER_VALIDATE_URL) !== false;
    $scheme = strtolower((string) parse_url($webhookUrl, PHP_URL_SCHEME));
    if (!$isUrlValid || !in_array($scheme, ["http", "https"], true)) {
        header("Location: staff_panel.php");
        exit;
    }
}
$webhookValue = $webhookUrl !== "" ? $webhookUrl : null;

if ($title === "" || $description === "" || $questions === "") {
    header("Location: staff_panel.php");
    exit;
}

$now = date("Y-m-d H:i:s");

if ($id > 0) {
    if ($hasWebhookColumn) {
        db_execute(
            "UPDATE application_forms SET title = ?, description = ?, questions = ?, type = ?, visibility = ?, webhook_url = ?, updated_at = ? WHERE id = ?",
            [$title, $description, $questions, $type, $visibility, $webhookValue, $now, $id]
        );
    } else {
        db_execute(
            "UPDATE application_forms SET title = ?, description = ?, questions = ?, type = ?, visibility = ?, updated_at = ? WHERE id = ?",
            [$title, $description, $questions, $type, $visibility, $now, $id]
        );
    }
} else {
    if ($hasWebhookColumn) {
        db_execute(
            "INSERT INTO application_forms (title, description, questions, type, visibility, webhook_url, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            [$title, $description, $questions, $type, $visibility, $webhookValue, $now, $now]
        );
    } else {
        db_execute(
            "INSERT INTO application_forms (title, description, questions, type, visibility, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?)",
            [$title, $description, $questions, $type, $visibility, $now, $now]
        );
    }
}

header("Location: staff_panel.php");
exit;
