<section class="page-head">
    <p class="eyebrow">Staff-panel</p>
    <h1>Kontrolpanel</h1>
    <p>Administrer roller, brugeradgang og regler fra samme sted.</p>
</section>

<nav class="staff-tabs">
    <a href="#users">Brugere</a>
    <?php if (can('staff.manage')): ?>
        <a href="#roles">Roller</a>
    <?php endif; ?>
    <?php if (can('rules.manage')): ?>
        <a href="#rules">Regler</a>
    <?php endif; ?>
</nav>

<section class="staff-section" id="users">
    <div class="section-title">
        <div>
            <p class="eyebrow">Brugere</p>
            <h2>Brugere og adgang</h2>
        </div>
    </div>

    <?php if (can('staff.manage')): ?>
        <form class="editor inline-form" method="post" action="<?= e(url('/staff/role')) ?>">
            <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
            <input id="steamid" name="steamid" placeholder="SteamID64" required>
            <select name="role" required>
                <?php foreach ($roles as $key => $role): ?>
                    <option value="<?= e($key) ?>"><?= e($role['label'] ?? $key) ?></option>
                <?php endforeach; ?>
            </select>
            <button class="button primary" type="submit">Opdater rolle</button>
        </form>
    <?php endif; ?>

    <section class="table-wrap">
        <table>
            <thead>
                <tr>
                    <th>Navn</th>
                    <th>SteamID</th>
                    <th>Rolle</th>
                    <th>Discord</th>
                    <th>Server</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($users as $row): ?>
                    <tr>
                        <td><?= e($row['name'] ?? 'Ukendt') ?></td>
                        <td><?= e($row['steamid'] ?? '') ?></td>
                        <td><?= e($roles[$row['role'] ?? 'member']['label'] ?? ($row['role'] ?? 'member')) ?></td>
                        <td><?= !empty($row['discord_authed']) ? 'Godkendt' : 'Ikke godkendt' ?></td>
                        <td><?= !empty($row['server_staff']) ? 'Staff' : 'Spiller' ?></td>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </section>
</section>

<?php if (can('staff.manage')): ?>
    <section class="staff-section" id="roles">
        <div class="section-title">
            <div>
                <p class="eyebrow">Rettigheder</p>
                <h2>Roller</h2>
            </div>
        </div>

        <form class="editor inline-form" method="post" action="<?= e(url('/staff/roles/add')) ?>">
            <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
            <input name="label" placeholder="Ny rolle, fx Hjælper" required>
            <button class="button primary" type="submit">Tilføj rolle</button>
        </form>

        <form class="role-grid" method="post" action="<?= e(url('/staff/roles')) ?>">
            <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
            <?php foreach ($roles as $key => $role): ?>
                <article class="role-card">
                    <label>Rollenavn</label>
                    <input name="roles[<?= e($key) ?>][label]" value="<?= e($role['label'] ?? $key) ?>">
                    <div class="permission-list">
                        <?php foreach ($permissions as $permission): ?>
                            <label>
                                <input
                                    type="checkbox"
                                    name="roles[<?= e($key) ?>][permissions][]"
                                    value="<?= e($permission) ?>"
                                    <?= in_array('*', $role['permissions'] ?? [], true) || in_array($permission, $role['permissions'] ?? [], true) ? 'checked' : '' ?>
                                >
                                <?= e($permission) ?>
                            </label>
                        <?php endforeach; ?>
                        <label>
                            <input
                                type="checkbox"
                                name="roles[<?= e($key) ?>][permissions][]"
                                value="*"
                                <?= in_array('*', $role['permissions'] ?? [], true) ? 'checked' : '' ?>
                            >
                            alle rettigheder
                        </label>
                    </div>
                </article>
            <?php endforeach; ?>
            <button class="button primary save-wide" type="submit">Gem roller</button>
        </form>
    </section>
<?php endif; ?>

<?php if (can('rules.manage')): ?>
    <section class="staff-section" id="rules">
        <div class="section-title">
            <div>
                <p class="eyebrow">Regler</p>
                <h2>Regler og kategorier</h2>
            </div>
        </div>

        <section class="grid two align-start">
            <form class="editor" method="post" action="<?= e(url('/staff/rules/category')) ?>">
                <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
                <label>Ny kategori</label>
                <input name="title" placeholder="Kategorinavn" required>
                <input name="description" placeholder="Kort beskrivelse">
                <button class="button primary" type="submit">Tilføj kategori</button>
            </form>

            <form class="editor" method="post" action="<?= e(url('/staff/rules/rule')) ?>">
                <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
                <label>Ny regel</label>
                <select name="category_id" required>
                    <?php foreach ($rules as $category): ?>
                        <option value="<?= e($category['id'] ?? '') ?>"><?= e($category['title'] ?? 'Kategori') ?></option>
                    <?php endforeach; ?>
                </select>
                <input name="title" placeholder="Regeltitel" required>
                <textarea name="body" rows="4" placeholder="Regeltekst"></textarea>
                <button class="button primary" type="submit">Tilføj regel</button>
            </form>
        </section>

        <form class="rules-admin" method="post" action="<?= e(url('/rules/save')) ?>">
            <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
            <?php foreach ($rules as $category): ?>
                <article class="category-editor">
                    <div class="category-editor-head">
                        <input name="categories[<?= e($category['id'] ?? '') ?>][order]" value="<?= e($category['order'] ?? 1) ?>" inputmode="numeric" aria-label="Kategori rækkefølge">
                        <input name="categories[<?= e($category['id'] ?? '') ?>][title]" value="<?= e($category['title'] ?? '') ?>" aria-label="Kategori titel">
                    </div>
                    <input name="categories[<?= e($category['id'] ?? '') ?>][description]" value="<?= e($category['description'] ?? '') ?>" aria-label="Kategori beskrivelse">

                    <?php foreach (($category['rules'] ?? []) as $rule): ?>
                        <div class="rule-editor">
                            <input name="categories[<?= e($category['id'] ?? '') ?>][rules][<?= e($rule['id'] ?? '') ?>][order]" value="<?= e($rule['order'] ?? 1) ?>" inputmode="numeric" aria-label="Regel rækkefølge">
                            <input name="categories[<?= e($category['id'] ?? '') ?>][rules][<?= e($rule['id'] ?? '') ?>][title]" value="<?= e($rule['title'] ?? '') ?>" aria-label="Regel titel">
                            <textarea name="categories[<?= e($category['id'] ?? '') ?>][rules][<?= e($rule['id'] ?? '') ?>][body]" rows="3" aria-label="Regeltekst"><?= e($rule['body'] ?? '') ?></textarea>
                        </div>
                    <?php endforeach; ?>
                </article>
            <?php endforeach; ?>
            <button class="button primary save-wide" type="submit">Gem regler</button>
        </form>
    </section>
<?php endif; ?>
