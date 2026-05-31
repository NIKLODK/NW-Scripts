<section class="page-head compact">
    <p class="eyebrow">Overblik</p>
    <h1>Velkommen, <?= e($user['name'] ?? 'spiller') ?></h1>
    <p>Din rolle er <strong><?= e(user_role($user)['label'] ?? 'Medlem') ?></strong>.</p>
</section>

<section class="profile-strip">
    <div class="avatar">
        <?php if (!empty($user['avatar'])): ?>
            <img src="<?= e($user['avatar']) ?>" alt="">
        <?php else: ?>
            <?= e(strtoupper(substr($user['name'] ?? 'S', 0, 1))) ?>
        <?php endif; ?>
    </div>
    <div>
        <strong><?= e($user['name'] ?? '') ?></strong>
        <span><?= e($user['steamid'] ?? '') ?></span>
    </div>
</section>

<section class="grid two">
    <article>
        <h2>Discord-godkendelse</h2>
        <p><?= !empty($user['discord_authed']) ? 'Din Discord er markeret som godkendt.' : 'Discord-godkendelse er klar som hook. Slå integrationen til, når botten/API\'et er koblet på.' ?></p>
    </article>
    <article>
        <h2>Server-staff</h2>
        <p><?= !empty($user['server_staff']) ? 'dxrp/server-export markerer dig som staff.' : 'Server-staff kan synkroniseres fra dxrp export URL i config.' ?></p>
    </article>
</section>

<?php $modules = visible_staff_modules($user); ?>
<?php if ($modules): ?>
    <section class="page-head compact">
        <p class="eyebrow">Staff</p>
        <h1>Dine værktøjer</h1>
    </section>
    <section class="grid three">
        <?php foreach ($modules as $module): ?>
            <article>
                <h2><?= e($module['title']) ?></h2>
                <p><?= e($module['body']) ?></p>
            </article>
        <?php endforeach; ?>
    </section>
<?php endif; ?>
