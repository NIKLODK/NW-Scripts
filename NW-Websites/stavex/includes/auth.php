<?php
require_once __DIR__ . "/config.php";

if (session_status() !== PHP_SESSION_ACTIVE) {
    session_start();
}

function discord_api_request(string $endpoint, string $accessToken): array
{
    $url = "https://discord.com/api" . $endpoint;
    $ch = curl_init($url);

    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => [
            "Authorization: Bearer {$accessToken}",
        ],
    ]);

    $response = curl_exec($ch);
    $status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($status < 200 || $status >= 300 || $response === false) {
        return [];
    }

    $decoded = json_decode($response, true);
    return is_array($decoded) ? $decoded : [];
}

function is_logged_in(): bool
{
    return isset($_SESSION["discord_user"]);
}

function discord_user(): ?array
{
    return $_SESSION["discord_user"] ?? null;
}

function is_whitelisted(): bool
{
    return $_SESSION["is_whitelisted"] ?? false;
}

function is_staff(): bool
{
    return $_SESSION["is_staff"] ?? false;
}

function is_admin(): bool
{
    return $_SESSION["is_admin"] ?? false;
}

function logout(): void
{
    session_destroy();
}
