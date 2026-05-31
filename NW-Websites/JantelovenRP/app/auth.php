<?php

declare(strict_types=1);

function current_user(): ?array
{
    $steamId = $_SESSION['steamid'] ?? null;
    if (!is_string($steamId)) {
        return null;
    }

    $users = read_json('users');
    return $users[$steamId] ?? null;
}

function login_url(): string
{
    $return = absolute_url('/steam/callback');
    $params = [
        'openid.ns' => 'http://specs.openid.net/auth/2.0',
        'openid.mode' => 'checkid_setup',
        'openid.return_to' => $return,
        'openid.realm' => origin_url(),
        'openid.identity' => 'http://specs.openid.net/auth/2.0/identifier_select',
        'openid.claimed_id' => 'http://specs.openid.net/auth/2.0/identifier_select',
    ];

    return 'https://steamcommunity.com/openid/login?' . http_build_query($params);
}

function origin_url(): string
{
    $https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') || (($_SERVER['SERVER_PORT'] ?? '') === '443');
    $scheme = $https ? 'https' : 'http';
    $host = $_SERVER['HTTP_HOST'] ?? 'localhost';
    return $scheme . '://' . $host;
}

function absolute_url(string $path): string
{
    return origin_url() . url($path);
}

function handle_steam_callback(): void
{
    if (($_GET['openid_mode'] ?? $_GET['openid.mode'] ?? '') !== 'id_res') {
        redirect_to('/');
    }

    $params = $_GET;
    $params['openid.mode'] = 'check_authentication';

    $context = stream_context_create([
        'http' => [
            'method' => 'POST',
            'header' => "Content-Type: application/x-www-form-urlencoded\r\n",
            'content' => http_build_query($params),
            'timeout' => 8,
        ],
    ]);

    $response = @file_get_contents('https://steamcommunity.com/openid/login', false, $context);
    if (!is_string($response) || !str_contains($response, 'is_valid:true')) {
        http_response_code(403);
        exit('Steam-login kunne ikke verificeres.');
    }

    $claimed = $_GET['openid_claimed_id'] ?? $_GET['openid.claimed_id'] ?? '';
    if (!is_string($claimed) || !preg_match('/\/id\/(\d+)$/', $claimed, $matches)) {
        http_response_code(403);
        exit('SteamID blev ikke fundet.');
    }

    $steamId = $matches[1];
    upsert_steam_user($steamId);
    $_SESSION['steamid'] = $steamId;
    redirect_to(can('staff.view') || can('rules.manage') || can('staff.manage') ? '/staff' : '/');
}

function test_login(): never
{
    if (!(bool) config('test_login_enabled', false)) {
        http_response_code(404);
        exit('Test-login er slået fra.');
    }

    $steamId = '90000000000000001';
    $users = read_json('users');
    $users[$steamId] = [
        'steamid' => $steamId,
        'name' => 'Test Staff',
        'avatar' => '',
        'role' => 'owner',
        'discord_authed' => true,
        'server_staff' => true,
    ];

    write_json('users', $users);
    $_SESSION['steamid'] = $steamId;
    redirect_to('/staff');
}

function upsert_steam_user(string $steamId): void
{
    $users = read_json('users');
    $profile = fetch_steam_profile($steamId);
    $existing = $users[$steamId] ?? [];

    $ownerIds = array_map('strval', config('owner_steamids', []));
    $hasOwner = storage_has_owner();
    $shouldBootstrapOwner = !$hasOwner && (bool) config('first_login_owner', true);
    $defaultRole = (in_array($steamId, $ownerIds, true) || $shouldBootstrapOwner)
        ? 'owner'
        : ($existing['role'] ?? 'member');

    $users[$steamId] = [
        'steamid' => $steamId,
        'name' => $profile['personaname'] ?? $existing['name'] ?? ('Steam ' . substr($steamId, -5)),
        'avatar' => $profile['avatarfull'] ?? $existing['avatar'] ?? '',
        'role' => $defaultRole,
        'discord_authed' => (bool) ($existing['discord_authed'] ?? false),
        'server_staff' => (bool) ($existing['server_staff'] ?? false),
    ];

    write_json('users', $users);
}

function storage_has_owner(): bool
{
    foreach (read_json('users') as $user) {
        if (($user['role'] ?? '') === 'owner') {
            return true;
        }
    }

    return false;
}

function fetch_steam_profile(string $steamId): array
{
    $key = (string) config('steam_api_key', '');
    if ($key === '') {
        return [];
    }

    $url = 'https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?' . http_build_query([
        'key' => $key,
        'steamids' => $steamId,
    ]);

    $json = @file_get_contents($url);
    $data = json_decode((string) $json, true);
    return $data['response']['players'][0] ?? [];
}

function logout(): never
{
    $_SESSION = [];
    session_destroy();
    redirect_to('/');
}
