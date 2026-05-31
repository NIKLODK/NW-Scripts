<?php

declare(strict_types=1);

require __DIR__ . '/../app/bootstrap.php';

$path = request_path();
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($path === '/steam/callback') {
    handle_steam_callback();
}

if ($path === '/logout') {
    logout();
}

if ($path === '/test-login') {
    test_login();
}

if ($method === 'POST' && $path === '/rules/save') {
    require_permission('rules.manage');
    require_csrf();

    $categories = [];
    foreach (($_POST['categories'] ?? []) as $categoryId => $category) {
        if (!is_array($category)) {
            continue;
        }

        $rules = [];
        foreach (($category['rules'] ?? []) as $ruleId => $rule) {
            if (!is_array($rule)) {
                continue;
            }
            $title = trim((string) ($rule['title'] ?? ''));
            $body = trim((string) ($rule['body'] ?? ''));
            if ($title === '' && $body === '') {
                continue;
            }
            $rules[] = [
                'id' => slug_id((string) $ruleId, 'rule-' . (count($rules) + 1)),
                'title' => $title !== '' ? $title : 'Regel',
                'body' => $body,
                'order' => (int) ($rule['order'] ?? (count($rules) + 1)),
            ];
        }
        usort($rules, fn (array $a, array $b): int => (int) $a['order'] <=> (int) $b['order']);

        $title = trim((string) ($category['title'] ?? ''));
        if ($title === '' && $rules === []) {
            continue;
        }

        $categories[] = [
            'id' => slug_id((string) $categoryId, 'category-' . (count($categories) + 1)),
            'title' => $title !== '' ? $title : 'Kategori',
            'description' => trim((string) ($category['description'] ?? '')),
            'order' => (int) ($category['order'] ?? (count($categories) + 1)),
            'rules' => $rules,
        ];
    }
    usort($categories, fn (array $a, array $b): int => (int) $a['order'] <=> (int) $b['order']);

    write_json('rules', $categories);
    redirect_to('/staff#rules');
}

if ($method === 'POST' && $path === '/staff/rules/category') {
    require_permission('rules.manage');
    require_csrf();

    $rules = normalize_rules(read_json('rules'));
    $title = trim((string) ($_POST['title'] ?? ''));
    if ($title !== '') {
        $rules[] = [
            'id' => slug_id($title, 'category-' . (count($rules) + 1)),
            'title' => $title,
            'description' => trim((string) ($_POST['description'] ?? '')),
            'order' => count($rules) + 1,
            'rules' => [],
        ];
        write_json('rules', $rules);
    }
    redirect_to('/staff#rules');
}

if ($method === 'POST' && $path === '/staff/rules/rule') {
    require_permission('rules.manage');
    require_csrf();

    $rules = normalize_rules(read_json('rules'));
    $categoryId = (string) ($_POST['category_id'] ?? '');
    $title = trim((string) ($_POST['title'] ?? ''));
    $body = trim((string) ($_POST['body'] ?? ''));

    foreach ($rules as &$category) {
        if (($category['id'] ?? '') !== $categoryId || $title === '') {
            continue;
        }
        $category['rules'][] = [
            'id' => slug_id($title, 'rule-' . (count($category['rules']) + 1)),
            'title' => $title,
            'body' => $body,
            'order' => count($category['rules']) + 1,
        ];
    }
    unset($category);

    write_json('rules', $rules);
    redirect_to('/staff#rules');
}

if ($method === 'POST' && $path === '/staff/role') {
    require_permission('staff.manage');
    require_csrf();

    $steamId = preg_replace('/\D+/', '', (string) ($_POST['steamid'] ?? ''));
    $role = (string) ($_POST['role'] ?? 'member');
    $roles = read_json('roles');

    if ($steamId === '' || !isset($roles[$role])) {
        render('error', ['title' => 'Rolle blev ikke gemt', 'message' => 'SteamID eller rolle er ugyldig.']);
        exit;
    }

    $users = read_json('users');
    $users[$steamId] ??= [
        'steamid' => $steamId,
        'name' => 'Steam ' . substr($steamId, -5),
        'avatar' => '',
        'discord_authed' => false,
        'server_staff' => false,
    ];
    $users[$steamId]['role'] = $role;
    write_json('users', $users);
    redirect_to('/staff');
}

if ($method === 'POST' && $path === '/staff/roles') {
    require_permission('staff.manage');
    require_csrf();

    $roles = [];
    foreach (($_POST['roles'] ?? []) as $roleKey => $role) {
        if (!is_array($role)) {
            continue;
        }
        $key = slug_id((string) $roleKey, 'role-' . (count($roles) + 1));
        $label = trim((string) ($role['label'] ?? ''));
        if ($label === '') {
            continue;
        }
        $perms = array_values(array_filter((array) ($role['permissions'] ?? []), 'is_string'));
        $roles[$key] = [
            'label' => $label,
            'permissions' => $perms,
        ];
    }

    write_json('roles', $roles);
    redirect_to('/staff#roles');
}

if ($method === 'POST' && $path === '/staff/roles/add') {
    require_permission('staff.manage');
    require_csrf();

    $roles = read_json('roles');
    $label = trim((string) ($_POST['label'] ?? ''));
    if ($label !== '') {
        $roles[slug_id($label, 'role-' . (count($roles) + 1))] = [
            'label' => $label,
            'permissions' => [],
        ];
        write_json('roles', $roles);
    }
    redirect_to('/staff#roles');
}

switch ($path) {
    case '/':
        $users = read_json('users');
        $roles = read_json('roles');
        $staffMembers = array_values(array_filter($users, static function (array $user): bool {
            return !empty($user['server_staff']);
        }));
        usort($staffMembers, static function (array $a, array $b): int {
            $priority = ['owner' => 0, 'admin' => 1, 'moderator' => 2, 'member' => 3];
            $left = $priority[$a['role'] ?? 'member'] ?? 9;
            $right = $priority[$b['role'] ?? 'member'] ?? 9;
            if ($left !== $right) {
                return $left <=> $right;
            }
            return strcasecmp((string) ($a['name'] ?? ''), (string) ($b['name'] ?? ''));
        });
        $staffMembers = array_map(static function (array $user) use ($roles): array {
            $roleKey = (string) ($user['role'] ?? 'member');
            $user['role_label'] = (string) ($roles[$roleKey]['label'] ?? ucfirst($roleKey));
            return $user;
        }, $staffMembers);

        $ruleCategories = normalize_rules(read_json('rules'));
        $ruleCount = 0;
        foreach ($ruleCategories as $category) {
            $ruleCount += count($category['rules'] ?? []);
        }

        render('home', [
            'title' => 'Forside',
            'donators' => read_json('donators'),
            'staffMembers' => $staffMembers,
            'ruleCount' => $ruleCount,
        ]);
        break;

    case '/rules':
        render('rules', ['title' => 'Regler', 'rules' => normalize_rules(read_json('rules'))]);
        break;

    case '/donation':
        render('donation', ['title' => 'Donation', 'donators' => read_json('donators')]);
        break;

    case '/dashboard':
        (can('staff.view') || can('rules.manage') || can('staff.manage')) ? redirect_to('/staff') : redirect_to('/');
        break;

    case '/staff':
        (can('staff.view') || can('rules.manage') || can('staff.manage'))
            ? render('staff', [
                'title' => 'Staff',
                'users' => read_json('users'),
                'roles' => read_json('roles'),
                'rules' => normalize_rules(read_json('rules')),
                'permissions' => ['rules.manage', 'staff.view', 'staff.manage'],
            ])
            : redirect_to('/');
        break;

    default:
        http_response_code(404);
        render('error', ['title' => '404', 'message' => 'Siden findes ikke.']);
}
