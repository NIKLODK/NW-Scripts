<?php

declare(strict_types=1);

function user_role(?array $user = null): array
{
    $user ??= current_user();
    $roles = read_json('roles');
    $roleKey = $user['role'] ?? 'member';
    return $roles[$roleKey] ?? $roles['member'] ?? ['label' => 'Medlem', 'permissions' => []];
}

function can(string $permission, ?array $user = null): bool
{
    $user ??= current_user();
    if (!$user) {
        return false;
    }

    $perms = user_role($user)['permissions'] ?? [];
    return in_array('*', $perms, true) || in_array($permission, $perms, true);
}

function require_permission(string $permission): void
{
    if (!can($permission)) {
        http_response_code(403);
        render('error', ['title' => 'Ingen adgang', 'message' => 'Du har ikke rettighed til denne side.']);
        exit;
    }
}

function visible_staff_modules(?array $user = null): array
{
    $user ??= current_user();
    if (!$user) {
        return [];
    }

    $modules = [];
    if (can('staff.view', $user) || !empty($user['discord_authed']) || !empty($user['server_staff'])) {
        $modules[] = ['title' => 'Staff-status', 'body' => 'Du har adgang til staff-overblik og interne links.'];
    }
    if (can('rules.manage', $user)) {
        $modules[] = ['title' => 'Regler', 'body' => 'Du kan opdatere reglerne direkte fra hjemmesiden.'];
    }
    if (can('staff.manage', $user)) {
        $modules[] = ['title' => 'Roller', 'body' => 'Du kan give staff-roller og rettigheder.'];
    }

    return $modules;
}
