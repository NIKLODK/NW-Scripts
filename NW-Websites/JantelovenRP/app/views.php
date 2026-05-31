<?php

declare(strict_types=1);

function render(string $view, array $data = []): void
{
    extract($data, EXTR_SKIP);
    $user = current_user();
    $title = $title ?? config('site_name');

    require APP_PATH . '/views/layout.php';
}

function active(string $path): string
{
    return request_path() === $path ? 'is-active' : '';
}
