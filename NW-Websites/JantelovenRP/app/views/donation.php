<section class="page-head">
    <p class="eyebrow">Support</p>
    <h1>Donation</h1>
    <p>Støt serveren og hjælp med drift, udvikling og fællesskabsevents. Donationer giver ikke ret til at bryde reglerne.</p>
</section>

<section class="donation-panel">
    <div>
        <h2>Support JantelovenRP</h2>
        <p>Donationer går til serverdrift, udvikling og forbedringer for spillerne.</p>
    </div>
    <a class="button primary" href="<?= e(config('discord_invite')) ?>">Donér via Discord</a>
</section>

<section class="donators-section podium-section">
    <div class="section-head">
        <p class="eyebrow">Supportere</p>
        <h2>Topdonatorer</h2>
    </div>

    <?php $topDonators = array_slice($donators ?? [], 0, 3); ?>
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
</section>
