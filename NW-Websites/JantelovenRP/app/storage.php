<?php

declare(strict_types=1);

function data_file(string $name): string
{
    return DATA_PATH . '/' . $name . '.json';
}

function read_json(string $name, array $fallback = []): array
{
    $file = data_file($name);
    if (!is_file($file)) {
        return $fallback;
    }

    $json = file_get_contents($file);
    $data = json_decode((string) $json, true);
    return is_array($data) ? $data : $fallback;
}

function write_json(string $name, array $data): void
{
    file_put_contents(
        data_file($name),
        json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
        LOCK_EX
    );
}

function normalize_rules(array $rules): array
{
    if ($rules === []) {
        return [];
    }

    $first = reset($rules);
    if (is_array($first) && array_key_exists('rules', $first)) {
        foreach ($rules as &$category) {
            $category['rules'] = array_values($category['rules'] ?? []);
            usort($category['rules'], fn (array $a, array $b): int => (int) ($a['order'] ?? 0) <=> (int) ($b['order'] ?? 0));
        }
        unset($category);
        usort($rules, fn (array $a, array $b): int => (int) ($a['order'] ?? 0) <=> (int) ($b['order'] ?? 0));
        return $rules;
    }

    return [
        [
            'id' => 'general',
            'title' => 'Generelle regler',
            'description' => 'Grundreglerne for serveren og fællesskabet.',
            'order' => 1,
            'rules' => array_map(static function (array $rule, int $index): array {
                return [
                    'id' => (string) ($rule['id'] ?? ('rule-' . ($index + 1))),
                    'title' => (string) ($rule['title'] ?? 'Regel'),
                    'body' => (string) ($rule['body'] ?? ''),
                    'order' => $index + 1,
                ];
            }, $rules, array_keys($rules)),
        ],
    ];
}

function slug_id(string $value, string $fallback): string
{
    $slug = strtolower(trim(preg_replace('/[^a-zA-Z0-9]+/', '-', $value) ?? '', '-'));
    return $slug !== '' ? $slug : $fallback;
}

function seed_storage(array $config): void
{
    if (!is_file(data_file('rules'))) {
        write_json('rules', [
            [
                'id' => 'general',
                'title' => 'Generelle regler',
                'description' => 'Grundreglerne for serveren og fællesskabet.',
                'order' => 1,
                'rules' => [
                    [
                        'id' => 'respect',
                        'title' => 'Respekt og opførsel',
                        'body' => 'Behandl andre spillere og staff ordentligt. Racisme, chikane, trusler og unødig toxic adfærd accepteres ikke.',
                        'order' => 1,
                    ],
                ],
            ],
            [
                'id' => 'roleplay',
                'title' => 'Roleplay-regler',
                'description' => 'Regler for scenarier, karakterer og handlinger in-game.',
                'order' => 2,
                'rules' => [
                    [
                        'id' => 'stay-character',
                        'title' => 'Bliv i karakter',
                        'body' => 'Hold dig i karakter under scenarier. OOC-snak skal holdes ude af roleplay.',
                        'order' => 1,
                    ],
                ],
            ],
            [
                'id' => 'support',
                'title' => 'Support og Discord',
                'description' => 'Sådan håndteres hjælp, klager og kontakt til staff.',
                'order' => 3,
                'rules' => [
                    [
                        'id' => 'tickets',
                        'title' => 'Brug tickets',
                        'body' => 'Har du brug for hjælp, skal du oprette en ticket på Discord.',
                        'order' => 1,
                    ],
                ],
            ],
        ]);
    }

    if (!is_file(data_file('roles'))) {
        write_json('roles', [
            'owner' => [
                'label' => 'Ejer',
                'permissions' => ['*'],
            ],
            'admin' => [
                'label' => 'Admin',
                'permissions' => ['rules.manage', 'staff.view', 'staff.manage'],
            ],
            'moderator' => [
                'label' => 'Moderator',
                'permissions' => ['rules.manage', 'staff.view'],
            ],
            'member' => [
                'label' => 'Medlem',
                'permissions' => [],
            ],
        ]);
    }

    if (!is_file(data_file('donators'))) {
        write_json('donators', [
            [
                'name' => 'Dxura',
                'tier' => 'Grundlægger-supporter',
                'amount' => '1.250 DKK',
            ],
            [
                'name' => 'Nordic',
                'tier' => 'Elite-supporter',
                'amount' => '750 DKK',
            ],
            [
                'name' => 'Mikkel',
                'tier' => 'Supporter',
                'amount' => '500 DKK',
            ],
            [
                'name' => 'Oliver',
                'tier' => 'Supporter',
                'amount' => '350 DKK',
            ],
            [
                'name' => 'Sebastian',
                'tier' => 'Supporter',
                'amount' => '250 DKK',
            ],
            [
                'name' => 'Emil',
                'tier' => 'Supporter',
                'amount' => '200 DKK',
            ],
        ]);
    }

    if (!is_file(data_file('users'))) {
        $users = [];
        foreach ($config['owner_steamids'] ?? [] as $steamId) {
            $users[(string) $steamId] = [
                'steamid' => (string) $steamId,
                'name' => 'Ejer',
                'avatar' => '',
                'role' => 'owner',
                'discord_authed' => false,
                'server_staff' => true,
            ];
        }
        write_json('users', $users);
    }
}
