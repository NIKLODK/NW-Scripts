<?php
require_once __DIR__ . "/config.php";

function discord_notifications_is_valid_url(string $url): bool
{
    if ($url === "") {
        return false;
    }

    $isUrlValid = filter_var($url, FILTER_VALIDATE_URL) !== false;
    $scheme = strtolower((string) parse_url($url, PHP_URL_SCHEME));
    return $isUrlValid && in_array($scheme, ["http", "https"], true);
}

function send_json_webhook(string $url, array $payload): bool
{
    if (!discord_notifications_is_valid_url($url)) {
        return false;
    }

    $json = json_encode($payload, JSON_UNESCAPED_UNICODE);
    if ($json === false) {
        return false;
    }

    if (function_exists("curl_init")) {
        $ch = curl_init($url);
        if ($ch === false) {
            return false;
        }
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $json,
            CURLOPT_HTTPHEADER => ["Content-Type: application/json"],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CONNECTTIMEOUT => 3,
            CURLOPT_TIMEOUT => 8,
        ]);
        curl_exec($ch);
        $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        return $status >= 200 && $status < 300;
    }

    $context = stream_context_create([
        "http" => [
            "method" => "POST",
            "header" => "Content-Type: application/json\r\n",
            "content" => $json,
            "timeout" => 8,
            "ignore_errors" => true,
        ],
    ]);

    $result = @file_get_contents($url, false, $context);
    if ($result === false && empty($http_response_header)) {
        return false;
    }

    $statusLine = $http_response_header[0] ?? "";
    if (preg_match("/\s(\d{3})\s/", $statusLine, $matches) !== 1) {
        return false;
    }
    $status = (int) $matches[1];
    return $status >= 200 && $status < 300;
}

function discord_bot_api_request(string $method, string $endpoint, array $payload = []): ?array
{
    if (!defined("DISCORD_BOT_TOKEN") || DISCORD_BOT_TOKEN === "") {
        return null;
    }

    $method = strtoupper(trim($method));
    if ($method === "") {
        $method = "GET";
    }

    $url = "https://discord.com/api/v10" . $endpoint;
    $hasBody = !empty($payload);
    $body = $hasBody ? json_encode($payload, JSON_UNESCAPED_UNICODE) : null;
    if ($hasBody && $body === false) {
        return null;
    }

    $headers = [
        "Authorization: Bot " . DISCORD_BOT_TOKEN,
        "Accept: application/json",
    ];
    if ($hasBody) {
        $headers[] = "Content-Type: application/json";
    }

    if (function_exists("curl_init")) {
        $ch = curl_init($url);
        if ($ch === false) {
            return null;
        }

        $curlOptions = [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_TIMEOUT => 8,
            CURLOPT_CUSTOMREQUEST => $method,
        ];
        if ($hasBody) {
            $curlOptions[CURLOPT_POSTFIELDS] = $body;
        }
        curl_setopt_array($ch, $curlOptions);

        $response = curl_exec($ch);
        $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($status < 200 || $status >= 300 || $response === false) {
            return null;
        }

        $decoded = json_decode($response, true);
        return is_array($decoded) ? $decoded : [];
    }

    $headerBlock = implode("\r\n", $headers);
    $context = stream_context_create([
        "http" => [
            "method" => $method,
            "header" => $headerBlock . "\r\n",
            "content" => $hasBody ? $body : "",
            "timeout" => 8,
            "ignore_errors" => true,
        ],
    ]);
    $response = @file_get_contents($url, false, $context);
    if ($response === false && empty($http_response_header)) {
        return null;
    }

    $statusLine = $http_response_header[0] ?? "";
    if (preg_match("/\s(\d{3})\s/", $statusLine, $matches) !== 1) {
        return null;
    }
    $status = (int) $matches[1];
    if ($status < 200 || $status >= 300) {
        return null;
    }

    $decoded = json_decode((string) $response, true);
    return is_array($decoded) ? $decoded : [];
}

function discord_truncate_text(string $text, int $maxLength): string
{
    if ($maxLength <= 0) {
        return "";
    }
    if (strlen($text) <= $maxLength) {
        return $text;
    }
    if ($maxLength <= 3) {
        return substr($text, 0, $maxLength);
    }
    return substr($text, 0, $maxLength - 3) . "...";
}

function discord_send_dm(string $discordUserId, string $message): bool
{
    $discordUserId = trim($discordUserId);
    $message = trim($message);

    if ($discordUserId === "" || $message === "") {
        return false;
    }

    $channel = discord_bot_api_request("POST", "/users/@me/channels", [
        "recipient_id" => $discordUserId,
    ]);
    $channelId = (string) ($channel["id"] ?? "");
    if ($channelId === "") {
        return false;
    }

    $message = discord_truncate_text($message, 1900);
    $sent = discord_bot_api_request("POST", "/channels/" . rawurlencode($channelId) . "/messages", [
        "content" => $message,
        "allowed_mentions" => ["parse" => []],
    ]);

    return $sent !== null;
}

function application_status_text(string $status): string
{
    return $status === "approved" ? "godkendt" : "afvist";
}

function build_application_status_dm_message(
    string $applicantName,
    string $applicationTitle,
    string $status,
    string $staffResponse = "",
    int $applicationId = 0
): string {
    $statusText = application_status_text($status);
    $message = "Hej " . $applicantName . "!\nDin ansøgning \"" . $applicationTitle . "\" er blevet " . $statusText . ".";
    if (trim($staffResponse) !== "") {
        $message .= "\n\nStaff svar:\n" . trim($staffResponse);
    }
    $applicationUrl = build_my_application_url($applicationId);
    if ($applicationUrl !== "") {
        $message .= "\n\nSe din ansøgning her:\n" . $applicationUrl;
    }
    return $message;
}

function site_base_url(): string
{
    if (defined("SITE_BASE_URL")) {
        $configured = trim((string) SITE_BASE_URL);
        if ($configured !== "" && discord_notifications_is_valid_url($configured)) {
            return rtrim($configured, "/");
        }
    }

    $redirect = defined("DISCORD_REDIRECT_URI") ? trim((string) DISCORD_REDIRECT_URI) : "";
    if ($redirect === "" || !discord_notifications_is_valid_url($redirect)) {
        return "";
    }

    $parts = parse_url($redirect);
    $scheme = $parts["scheme"] ?? "";
    $host = $parts["host"] ?? "";
    if ($scheme === "" || $host === "") {
        return "";
    }
    $port = isset($parts["port"]) ? ":" . (int) $parts["port"] : "";
    return $scheme . "://" . $host . $port;
}

function build_application_action_token(int $applicationId, string $status, int $expires): string
{
    if (!defined("DISCORD_APPLICATION_ACTION_SECRET")) {
        return "";
    }
    $secret = trim((string) DISCORD_APPLICATION_ACTION_SECRET);
    if ($secret === "") {
        return "";
    }
    $payload = $applicationId . "|" . $status . "|" . $expires;
    return hash_hmac("sha256", $payload, $secret);
}

function verify_application_action_token(int $applicationId, string $status, int $expires, string $token): bool
{
    if ($applicationId <= 0 || $token === "" || $expires < time()) {
        return false;
    }
    if (!in_array($status, ["approved", "denied"], true)) {
        return false;
    }
    $expected = build_application_action_token($applicationId, $status, $expires);
    if ($expected === "") {
        return false;
    }
    return hash_equals($expected, $token);
}

function build_application_action_url(int $applicationId, string $status): ?string
{
    if (!in_array($status, ["approved", "denied"], true)) {
        return null;
    }
    $baseUrl = site_base_url();
    if ($baseUrl === "") {
        return null;
    }

    $expires = time() + (7 * 24 * 60 * 60);
    $token = build_application_action_token($applicationId, $status, $expires);
    if ($token === "") {
        return null;
    }

    $query = http_build_query([
        "id" => $applicationId,
        "status" => $status,
        "expires" => $expires,
        "token" => $token,
    ]);
    return $baseUrl . "/application_action.php?" . $query;
}

function build_my_application_url(int $applicationId): string
{
    $baseUrl = site_base_url();
    if ($baseUrl === "") {
        return "";
    }
    if ($applicationId > 0) {
        return $baseUrl . "/applications.php#application-" . $applicationId;
    }
    return $baseUrl . "/applications.php";
}

function format_application_qa_for_discord(array $qaItems): string
{
    $blocks = [];
    foreach ($qaItems as $qaItem) {
        if (!is_array($qaItem)) {
            continue;
        }
        $question = trim((string) ($qaItem["question"] ?? ""));
        $answer = trim((string) ($qaItem["answer"] ?? ""));
        if ($question === "" && $answer === "") {
            continue;
        }
        if ($question === "") {
            $question = "Spørgsmål";
        }
        if ($answer === "") {
            $answer = "_Ingen svar_";
        }
        $answer = preg_replace("/\r\n|\r|\n/", "\n", $answer) ?? $answer;
        $blocks[] = "**" . $question . "**\n" . $answer;
        if (count($blocks) >= 8) {
            break;
        }
    }

    if (empty($blocks)) {
        return "_Ingen svar fundet._";
    }

    return discord_truncate_text(implode("\n\n", $blocks), 3900);
}

function build_new_application_payload(array $application, bool $forWebhook): array
{
    $siteName = defined("SITE_NAME") ? SITE_NAME : "Website";
    $applicationId = (int) ($application["id"] ?? 0);
    $formTitle = trim((string) ($application["form_title"] ?? ""));
    $formType = trim((string) ($application["type"] ?? ""));
    $applicantName = trim((string) ($application["applicant_name"] ?? "Ukendt"));
    $discordUserId = trim((string) ($application["discord_user_id"] ?? ""));
    $createdAt = trim((string) ($application["created_at"] ?? ""));
    $qaFormatted = format_application_qa_for_discord($application["question_answers"] ?? []);

    $applicantField = $discordUserId !== ""
        ? "<@" . $discordUserId . "> (" . $applicantName . ")"
        : $applicantName;

    $approveUrl = build_application_action_url($applicationId, "approved");
    $denyUrl = build_application_action_url($applicationId, "denied");

    $payload = [
        "content" => "Ny ansøgning modtaget.",
        "embeds" => [[
            "title" => "Ny ansøgning",
            "color" => 5814783,
            "fields" => [
                [
                    "name" => "Ansøgnings-ID",
                    "value" => (string) $applicationId,
                    "inline" => true,
                ],
                [
                    "name" => "Formular",
                    "value" => $formTitle !== "" ? $formTitle : "Ukendt",
                    "inline" => true,
                ],
                [
                    "name" => "Type",
                    "value" => $formType !== "" ? $formType : "general",
                    "inline" => true,
                ],
                [
                    "name" => "Ansøger",
                    "value" => $applicantField,
                    "inline" => false,
                ],
            ],
            "description" => $qaFormatted,
            "footer" => [
                "text" => $siteName . ($createdAt !== "" ? " • " . $createdAt : ""),
            ],
        ]],
        "allowed_mentions" => ["parse" => []],
    ];

    if ($approveUrl !== null && $denyUrl !== null) {
        $payload["components"] = [[
            "type" => 1,
            "components" => [
                [
                    "type" => 2,
                    "style" => 5,
                    "label" => "Godkend",
                    "url" => $approveUrl,
                ],
                [
                    "type" => 2,
                    "style" => 5,
                    "label" => "Afvis",
                    "url" => $denyUrl,
                ],
            ],
        ]];
    }

    if ($forWebhook) {
        $payload["username"] = $siteName . " Ansøgninger";
    }

    return $payload;
}

function send_discord_new_application_channel_message(array $application): bool
{
    if (!defined("DISCORD_APPLICATION_CHANNEL_ID")) {
        return false;
    }

    $channelId = trim((string) DISCORD_APPLICATION_CHANNEL_ID);
    if ($channelId === "") {
        return false;
    }

    $payload = build_new_application_payload($application, false);
    $result = discord_bot_api_request("POST", "/channels/" . rawurlencode($channelId) . "/messages", $payload);
    return $result !== null;
}

function send_discord_new_application_webhook(array $application): bool
{
    if (!defined("DISCORD_APPLICATION_WEBHOOK_URL")) {
        return false;
    }

    $webhookUrl = trim((string) DISCORD_APPLICATION_WEBHOOK_URL);
    if ($webhookUrl === "") {
        return false;
    }

    $payload = build_new_application_payload($application, true);
    return send_json_webhook($webhookUrl, $payload);
}

function send_discord_new_application_notification(array $application): bool
{
    if (send_discord_new_application_channel_message($application)) {
        return true;
    }
    return send_discord_new_application_webhook($application);
}
