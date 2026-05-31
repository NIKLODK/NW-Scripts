<section class="page-head">
    <p class="eyebrow">Fællesskab</p>
    <h1>Regler</h1>
    <p>Find reglerne efter kategori. Staff kan ændre kategorier og regler inde fra staff-panelet.</p>
</section>

<section class="rules-layout">
    <aside class="rules-nav">
        <?php foreach ($rules as $category): ?>
            <a href="#<?= e($category['id'] ?? '') ?>"><?= e($category['title'] ?? 'Kategori') ?></a>
        <?php endforeach; ?>
    </aside>

    <div class="rules-list">
        <?php foreach ($rules as $category): ?>
            <section class="rule-category" id="<?= e($category['id'] ?? '') ?>">
                <div class="category-head">
                    <span><?= e(str_pad((string) (int) ($category['order'] ?? 1), 2, '0', STR_PAD_LEFT)) ?></span>
                    <div>
                        <h2><?= e($category['title'] ?? 'Kategori') ?></h2>
                        <p><?= e($category['description'] ?? '') ?></p>
                    </div>
                </div>

                <?php foreach (($category['rules'] ?? []) as $index => $rule): ?>
                    <article class="rule">
                        <span><?= e(str_pad((string) ($index + 1), 2, '0', STR_PAD_LEFT)) ?></span>
                        <div>
                            <h3><?= e($rule['title'] ?? 'Regel') ?></h3>
                            <p><?= nl2br(e($rule['body'] ?? '')) ?></p>
                        </div>
                    </article>
                <?php endforeach; ?>
            </section>
        <?php endforeach; ?>
    </div>
</section>
