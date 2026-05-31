<?php
require_once __DIR__ . "/config.php";
require_once __DIR__ . "/db.php";

function staff_bot_enabled(): bool
{
    return defined("DISCORD_BOT_TOKEN") && DISCORD_BOT_TOKEN !== "";
}

function staff_sync_interval_minutes(): int
{
    if (defined("DISCORD_STAFF_SYNC_MINUTES")) {
        $value = (int) DISCORD_STAFF_SYNC_MINUTES;
        return $value > 0 ? $value : 10;
    }
    return 10;
}

function staff_meta_last_synced(): ?string
{
    $rows = db_fetch_all("SELECT last_synced_at FROM staff_meta WHERE id = 1");
    if (empty($rows)) {
        return null;
    }
    return $rows[0]["last_synced_at"] ?? null;
}

function staff_update_meta(string $timestamp): void
{
    db_execute(
        "INSERT INTO staff_meta (id, last_synced_at) VALUES (1, ?) ON DUPLICATE KEY UPDATE last_synced_at = VALUES(last_synced_at)",
        [$timestamp]
    );
}

function staff_should_sync(): bool
{
    if (!staff_bot_enabled()) {
        return false;
    }

    $lastSynced = staff_meta_last_synced();
    if (!$lastSynced) {
        return true;
    }

    $last = strtotime($lastSynced);
    if ($last === false) {
        return true;
    }

    $interval = staff_sync_interval_minutes() * 60;
    return (time() - $last) > $interval;
}

function discord_bot_request(string $endpoint): ?array
{
    if (!staff_bot_enabled()) {
        return null;
    }

    $url = "https://discord.com/api/v10" . $endpoint;
    $headers = [
        "Authorization: Bot " . DISCORD_BOT_TOKEN,
        "Accept: application/json",
    ];

    if (function_exists("curl_init")) {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_TIMEOUT => 8,
        ]);
        $response = curl_exec($ch);
        $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($status < 200 || $status >= 300 || $response === false) {
            return null;
        }

        $decoded = json_decode($response, true);
        return is_array($decoded) ? $decoded : null;
    }

    $context = stream_context_create([
        "http" => [
            "timeout" => 8,
            "header" => implode("\r\n", $headers) . "\r\n",
        ],
    ]);
    $response = @file_get_contents($url, false, $context);
    if ($response === false) {
        return null;
    }
    $decoded = json_decode($response, true);
    return is_array($decoded) ? $decoded : null;
}

function staff_avatar_url(string $guildId, string $userId, ?string $userAvatar, ?string $memberAvatar): ?string
{
    if ($memberAvatar) {
        return "https://cdn.discordapp.com/guilds/" . $guildId . "/users/" . $userId . "/avatars/" . $memberAvatar . ".png?size=128";
    }
    if ($userAvatar) {
        return "https://cdn.discordapp.com/avatars/" . $userId . "/" . $userAvatar . ".png?size=128";
    }
    return null;
}

function fetch_staff_members_from_discord(): ?array
{
    if (!defined("DISCORD_GUILD_ID") || !defined("DISCORD_UNTRUSTED_ROLE_ID")) {
        return null;
    }

    $guildId = DISCORD_GUILD_ID;
    $roleId = DISCORD_UNTRUSTED_ROLE_ID;
    $members = [];
    $after = "0";

    while (true) {
        $endpoint = "/guilds/" . rawurlencode($guildId) . "/members?limit=1000&after=" . rawurlencode($after);
        $batch = discord_bot_request($endpoint);
        if ($batch === null) {
            return null;
        }
        if (!is_array($batch) || empty($batch)) {
            break;
        }

        foreach ($batch as $member) {
            if (empty($member["roles"]) || !in_array($roleId, $member["roles"], true)) {
                continue;
            }
            $members[] = $member;
        }

        if (count($batch) < 1000) {
            break;
        }

        $last = end($batch);
        $after = $last["user"]["id"] ?? null;
        if (!$after) {
            break;
        }
    }

    return $members;
}

function staff_sync_members(bool $force = false): array
{
    if (!staff_bot_enabled()) {
        return ["ok" => false, "error" => "bot_token_missing"];
    }

    if (!$force && !staff_should_sync()) {
        return ["ok" => true, "skipped" => true];
    }

    $members = fetch_staff_members_from_discord();
    if ($members === null) {
        return ["ok" => false, "error" => "discord_fetch_failed"];
    }

    $now = gmdate("Y-m-d H:i:s");
    $activeIds = [];

    foreach ($members as $member) {
        $user = $member["user"] ?? null;
        if (!is_array($user) || empty($user["id"])) {
            continue;
        }

        $userId = (string) $user["id"];
        $username = $user["username"] ?? null;
        $displayName = $member["nick"] ?? ($user["global_name"] ?? $username);
        $avatarUrl = staff_avatar_url(
            DISCORD_GUILD_ID,
            $userId,
            $user["avatar"] ?? null,
            $member["avatar"] ?? null
        );

        db_execute(
            "INSERT INTO staff_members (discord_user_id, username, display_name, avatar_url, is_active, updated_at)
             VALUES (?, ?, ?, ?, 1, ?)
             ON DUPLICATE KEY UPDATE username = VALUES(username),
             display_name = VALUES(display_name),
             avatar_url = VALUES(avatar_url),
             is_active = 1,
             updated_at = VALUES(updated_at)",
            [$userId, $username, $displayName, $avatarUrl, $now]
        );

        $activeIds[] = $userId;
    }

    if (!empty($activeIds)) {
        $placeholders = implode(",", array_fill(0, count($activeIds), "?"));
        db_execute(
            "UPDATE staff_members SET is_active = 0 WHERE discord_user_id NOT IN (" . $placeholders . ")",
            $activeIds
        );
    }

    staff_update_meta($now);

    return [
        "ok" => true,
        "count" => count($activeIds),
    ];
}

function staff_maybe_sync(): void
{
    staff_sync_members(false);
}
