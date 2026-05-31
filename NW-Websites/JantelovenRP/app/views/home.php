<?php
$visibleStaff = $staffMembers ?? [];
$topDonators = array_slice($donators ?? [], 0, 3);
$restDonators = array_slice($donators ?? [], 3);
?>

<section class="hero home-hero">
    <div class="hero-copy">
        <p class="eyebrow">Dansk S&box roleplay</p>
        <h1>JantelovenRP</h1>
        <p class="lead">Et seriøst dansk roleplay-fællesskab med fokus på tydelige regler, aktivt staff og ordentlige scenarier.</p>

        <div class="hero-actions">
            <a class="button primary" href="<?= e(config('server_connect_url')) ?>">Forbind til serveren</a>
            <a class="button" href="<?= e(config('discord_invite')) ?>">Deltag i Discord</a>
        </div>
    </div>
</section>

<section class="info-section">
    <article>
        <span>01</span>
        <h2>Seriøst roleplay</h2>
        <p>Scenarier skal give mening, føles fair og skabe gode historier for alle spillere.</p>
    </article>
    <article>
        <span>02</span>
        <h2>Aktivt staff</h2>
        <p>Staff er synlige på forsiden og kan holde roller, regler og adgang samlet i panelet.</p>
    </article>
    <article>
        <span>03</span>
        <h2>Fællesskab</h2>
        <p>Donationer hjælper med drift, udvikling og events uden at ændre serverens fokus.</p>
    </article>
</section>

<section class="staff-showcase">
    <div class="section-head section-head-left">
        <p class="eyebrow">Staff</p>
        <h2>Staff</h2>
        <p>Alle profiler her er markeret som staff team på serveren.</p>
    </div>

    <?php if ($visibleStaff): ?>
        <div class="staff-marquee" aria-label="Staff på serveren">
            <div class="staff-track">
                <?php for ($loop = 0; $loop < 4; $loop++): ?>
                    <?php foreach ($visibleStaff as $staff): ?>
                        <?php
                        $discordUrl = (string) ($staff['discord_url'] ?? $staff['discord'] ?? '');
                        if ($discordUrl === '' && !empty($staff['discord_id'])) {
                            $discordUrl = 'https://discord.com/users/' . preg_replace('/\D+/', '', (string) $staff['discord_id']);
                        }
                        $discordUrl = $discordUrl !== '' ? $discordUrl : (string) config('discord_invite');
                        ?>
                        <a href="<?= e($discordUrl) ?>">
                            <span class="staff-marquee-avatar">
                                <?php if (!empty($staff['avatar'])): ?>
                                    <img src="<?= e($staff['avatar']) ?>" alt="<?= e($staff['name'] ?? 'Staff') ?>">
                                <?php else: ?>
                                    <?= e(strtoupper(substr((string) ($staff['name'] ?? 'S'), 0, 1))) ?>
                                <?php endif; ?>
                            </span>
                            <strong><?= e($staff['name'] ?? 'Staff') ?></strong>
                            <small><?= e($staff['role_label'] ?? 'Staff') ?></small>
                        </a>
                    <?php endforeach; ?>
                <?php endfor; ?>
            </div>
        </div>
    <?php else: ?>
        <div class="staff-empty">
            <strong>Ingen staff fundet</strong>
            <span>Når serveren markerer spillere som staff team, vises de her.</span>
        </div>
    <?php endif; ?>
</section>

<section class="donators-section podium-section">
    <div class="section-head">
        <p class="eyebrow">Supportere</p>
        <h2>Topdonatorer</h2>
    </div>

    <div class="podium">
        <?php foreach ([1, 0, 2] as $slot): ?>
            <?php if (!isset($topDonators[$slot])) { continue; } ?>
            <?php $donator = $topDonators[$slot]; ?>
            <article class="podium-card place-<?= e($slot + 1) ?>">
                <span>#<?= e($slot + 1) ?></span>
                <strong><?= e($donator['name'] ?? 'Ukendt') ?></strong>
                <small><?= e($donator['tier'] ?? 'Supporter') ?></small>
                <p><?= e($donator['amount'] ?? '') ?></p>
            </article>
        <?php endforeach; ?>
    </div>

    <?php if ($restDonators): ?>
        <div class="supporter-marquee" aria-label="Andre donatorer">
            <div class="supporter-track">
                <?php for ($loop = 0; $loop < 2; $loop++): ?>
                    <?php foreach ($restDonators as $index => $donator): ?>
                        <span>
                            #<?= e($index + 4) ?>
                            <?= e($donator['name'] ?? 'Ukendt') ?>
                            <strong><?= e($donator['amount'] ?? '') ?></strong>
                        </span>
                    <?php endforeach; ?>
                <?php endfor; ?>
            </div>
        </div>
    <?php endif; ?>
</section>
