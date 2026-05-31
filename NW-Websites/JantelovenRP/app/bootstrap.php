<?php

declare(strict_types=1);

session_name('janteloven_site');
session_start();

const APP_PATH = __DIR__;
const ROOT_PATH = __DIR__ . '/..';
const DATA_PATH = ROOT_PATH . '/data';

$config = require APP_PATH . '/config.php';

require APP_PATH . '/storage.php';
require APP_PATH . '/auth.php';
require APP_PATH . '/permissions.php';
require APP_PATH . '/views.php';

seed_storage($config);

function config(string $key, mixed $default = null): mixed
{
    global $config;
    return $config[$key] ?? $default;
}

function url(string $path = ''): string
{
    $base = rtrim((string) config('base_path', ''), '/');
    $path = '/' . ltrim($path, '/');
    return $base . ($path === '/' ? '' : $path);
}

function redirect_to(string $path): never
{
    header('Location: ' . url($path));
    exit;
}

function request_path(): string
{
    $uri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
    $base = rtrim((string) config('base_path', ''), '/');

    if ($base !== '' && str_starts_with(rawurldecode($uri), $base)) {
        $uri = substr(rawurldecode($uri), strlen($base));
    }

    $path = '/' . trim($uri, '/');
    return $path === '/public/index.php' ? '/' : $path;
}

function csrf_token(): string
{
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(32));
    }

    return $_SESSION['csrf'];
}

function require_csrf(): void
{
    $token = $_POST['csrf'] ?? '';
    if (!is_string($token) || !hash_equals(csrf_token(), $token)) {
        http_response_code(419);
        exit('Ugyldig session token.');
    }
}

function e(mixed $value): string
{
    return htmlspecialchars((string) $value, ENT_QUOTES, 'UTF-8');
}
