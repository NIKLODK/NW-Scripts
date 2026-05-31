<?php /** @var string $view */ ?>
<!doctype html>
<html lang="da">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex,nofollow">
    <title><?= e($title) ?> - <?= e(config('site_name')) ?></title>
    <link rel="stylesheet" href="<?= e(url('/public/assets/site.css')) ?>">
</head>
<body>
    <header class="topbar">
        <a class="brand" href="<?= e(url('/')) ?>">
            <span class="brand-mark">J</span>
            <span>
                <strong><?= e(config('site_name')) ?></strong>
                <small>Roleplay-fællesskab</small>
            </span>
        </a>

        <nav class="nav">
            <a class="<?= e(active('/')) ?>" href="<?= e(url('/')) ?>">Forside</a>
            <a class="<?= e(active('/rules')) ?>" href="<?= e(url('/rules')) ?>">Regler</a>
            <a class="<?= e(active('/donation')) ?>" href="<?= e(url('/donation')) ?>">Donation</a>
            <?php if (can('staff.view') || can('rules.manage') || can('staff.manage')): ?>
                <a class="<?= e(active('/staff')) ?>" href="<?= e(url('/staff')) ?>">Staff</a>
            <?php endif; ?>
        </nav>

        <div class="actions">
            <?php if ($user): ?>
                <a class="steam-pill" href="<?= e(url('/logout')) ?>"><?= e($user['name']) ?> · Log ud</a>
            <?php else: ?>
                <?php if (config('test_login_enabled', false)): ?>
                    <a class="test-pill" href="<?= e(url('/test-login')) ?>">Test-login</a>
                <?php endif; ?>
                <a class="steam-login" href="<?= e(login_url()) ?>" aria-label="Log ind med Steam">
                    <img src="https://community.steamstatic.com/public/images/signinthroughsteam/sits_01.png" alt="Log ind med Steam">
                </a>
            <?php endif; ?>
        </div>
    </header>

    <main>
        <?php require APP_PATH . '/views/' . $view . '.php'; ?>
    </main>

    <script src="<?= e(url('/public/assets/site.js')) ?>" defer></script>
</body>
</html>
