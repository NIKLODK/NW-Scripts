<?php
require_once __DIR__ . "/includes/auth.php";

if (!isset($_GET["code"])) {
    header("Location: index.php");
    exit;
}

$code = $_GET["code"];

$tokenRequest = [
    "client_id" => DISCORD_CLIENT_ID,
    "client_secret" => DISCORD_CLIENT_SECRET,
    "grant_type" => "authorization_code",
    "code" => $code,
    "redirect_uri" => DISCORD_REDIRECT_URI,
    "scope" => DISCORD_OAUTH_SCOPES,
];

$ch = curl_init("https://discord.com/api/oauth2/token");
curl_setopt_array($ch, [
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => http_build_query($tokenRequest),
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_HTTPHEADER => ["Content-Type: application/x-www-form-urlencoded"],
]);

$response = curl_exec($ch);
$status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($status < 200 || $status >= 300 || $response === false) {
    header("Location: index.php?error=oauth");
    exit;
}

$data = json_decode($response, true);
$accessToken = $data["access_token"] ?? null;

if (!$accessToken) {
    header("Location: index.php?error=token");
    exit;
}

$user = discord_api_request("/users/@me", $accessToken);
$member = discord_api_request("/users/@me/guilds/" . DISCORD_GUILD_ID . "/member", $accessToken);

$_SESSION["discord_user"] = $user;
$_SESSION["discord_member"] = $member;
$_SESSION["is_whitelisted"] = false;
$_SESSION["is_staff"] = false;
$_SESSION["is_admin"] = false;

if (!empty($member["roles"]) && in_array(DISCORD_WHITELIST_ROLE_ID, $member["roles"], true)) {
    $_SESSION["is_whitelisted"] = true;
}

if (!empty($member["roles"]) && in_array(DISCORD_STAFF_ROLE_ID, $member["roles"], true)) {
    $_SESSION["is_staff"] = true;
}

if (
    !empty($user["id"])
    && defined("DISCORD_SUPERUSER_IDS")
    && is_array(DISCORD_SUPERUSER_IDS)
    && in_array($user["id"], DISCORD_SUPERUSER_IDS, true)
) {
    $_SESSION["is_admin"] = true;
    $_SESSION["is_staff"] = true;
    $_SESSION["is_whitelisted"] = true;
}

header("Location: applications.php");
exit;
