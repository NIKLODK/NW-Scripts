<?php
require_once __DIR__ . "/includes/header.php";
require_once __DIR__ . "/includes/db.php";
require_once __DIR__ . "/includes/staff.php";
require_once __DIR__ . "/includes/application_lifecycle.php";

if (!is_staff() && !is_admin()) {
    http_response_code(403);
    echo "Ingen adgang";
    exit;
}

function staff_initials(string $name): string
{
    $trimmed = trim($name);
    if ($trimmed === "") {
        return "ST";
    }
    $parts = preg_split("/\s+/", $trimmed);
    $first = $parts[0] ?? "";
    $second = $parts[1] ?? "";
    $initials = substr($first, 0, 1) . ($second !== "" ? substr($second, 0, 1) : "");
    return strtoupper($initials);
}

$ruleCategories = db_fetch_all(
    "SELECT id, name, sort_order FROM rule_categories ORDER BY sort_order DESC, name ASC"
);
$rules = db_fetch_all(
    "SELECT r.id, r.category_id, r.title, r.body, rc.name AS category_name, rc.sort_order AS category_sort
     FROM rules r
     LEFT JOIN rule_categories rc ON rc.id = r.category_id
     ORDER BY
       CASE WHEN rc.id IS NULL THEN 1 ELSE 0 END,
       rc.sort_order DESC,
       rc.name ASC,
       r.id ASC"
);
$lawCategories = db_fetch_all(
    "SELECT id, name, sort_order FROM law_categories ORDER BY sort_order DESC, name ASC"
);
$laws = db_fetch_all(
    "SELECT l.id, l.category_id, l.title, l.body, lc.name AS category_name, lc.sort_order AS category_sort
     FROM laws l
     LEFT JOIN law_categories lc ON lc.id = l.category_id
     ORDER BY
       CASE WHEN lc.id IS NULL THEN 1 ELSE 0 END,
       lc.sort_order DESC,
       lc.name ASC,
       l.id ASC"
);
$donors = db_fetch_all(
    "SELECT d.discord_user_id, SUM(d.amount) AS total, l.nickname, l.opted_in, MAX(d.discord_name) AS last_name
     FROM donations d
     LEFT JOIN leaderboard_optin l ON l.discord_user_id = d.discord_user_id
     WHERE d.discord_user_id IS NOT NULL
     GROUP BY d.discord_user_id, l.nickname, l.opted_in
     ORDER BY total DESC"
);
application_cleanup_answered(3);

$applications = db_fetch_all(
    "SELECT a.id, a.type, a.applicant_name, a.discord_user_id, a.content, a.staff_response, a.status, a.created_at, a.answered_at, f.title
     FROM applications a
     LEFT JOIN application_forms f ON f.id = a.form_id
     ORDER BY (a.status = 'approved') DESC, a.created_at DESC"
);

$playerDiscordId = trim((string) ($_GET["player_discord_id"] ?? ""));
$playerLookup = null;
if ($playerDiscordId !== "") {
    $activeApplications = db_fetch_all(
        "SELECT a.id, a.type, f.title AS form_title, a.status, a.created_at, a.answered_at, a.content, a.staff_response, 'active' AS source
         FROM applications a
         LEFT JOIN application_forms f ON f.id = a.form_id
         WHERE a.discord_user_id = ?
         ORDER BY a.created_at DESC",
        [$playerDiscordId]
    );

    $historyApplications = [];
    if (application_history_exists()) {
        $historyApplications = db_fetch_all(
            "SELECT application_id AS id, type, form_title, final_status AS status, created_at, answered_at,
                    content, staff_response, 'history' AS source
             FROM application_history
             WHERE discord_user_id = ?
             ORDER BY created_at DESC",
            [$playerDiscordId]
        );
    }

    $combinedApplications = array_merge($activeApplications, $historyApplications);
    usort($combinedApplications, static function (array $a, array $b): int {
        return strcmp((string) ($b["created_at"] ?? ""), (string) ($a["created_at"] ?? ""));
    });

    $counts = [
        "total" => count($combinedApplications),
        "pending" => 0,
        "approved" => 0,
        "denied" => 0,
    ];
    $byType = [];
    foreach ($combinedApplications as $row) {
        $status = (string) ($row["status"] ?? "pending");
        if (isset($counts[$status])) {
            $counts[$status]++;
        }
        $typeLabel = trim((string) (($row["form_title"] ?? "") !== "" ? $row["form_title"] : ($row["type"] ?? "Ukendt")));
        if (!isset($byType[$typeLabel])) {
            $byType[$typeLabel] = 0;
        }
        $byType[$typeLabel]++;
    }
    arsort($byType);

    $playerLookup = [
        "discord_id" => $playerDiscordId,
        "counts" => $counts,
        "by_type" => $byType,
        "applications" => $combinedApplications,
    ];
}

$hasWebhookColumn = !empty(db_fetch_all("SHOW COLUMNS FROM application_forms LIKE 'webhook_url'"));
$formColumns = "id, title, description, questions, visibility, type";
if ($hasWebhookColumn) {
    $formColumns .= ", webhook_url";
}
$forms = db_fetch_all("SELECT {$formColumns} FROM application_forms ORDER BY created_at DESC");

staff_maybe_sync();
$staffMembers = db_fetch_all(
    "SELECT discord_user_id, username, display_name, avatar_url, title, sort_order, is_active
     FROM staff_members
     ORDER BY is_active DESC, sort_order DESC, display_name ASC"
);
$staffSyncStatus = $_GET["staff_sync"] ?? "";
$staffSyncError = $_GET["error"] ?? "";
$applicationDeletedStatus = $_GET["deleted"] ?? "";
?>

<main>
  <section class="staff-panel">
    <div class="section-heading">
      <h2>Staff Panel</h2>
      <p>Administration af donationer, regler og ansøgninger.</p>
    </div>

    <div class="panel-tabs">
      <button class="tab-btn" data-tab="staff">Staff</button>
      <button class="tab-btn" data-tab="rules">Regler</button>
      <button class="tab-btn" data-tab="laws">Lovgivning</button>
      <button class="tab-btn" data-tab="applications">Ansøgninger</button>
      <button class="tab-btn" data-tab="submissions">Sendte ansøgninger</button>
      <button class="tab-btn" data-tab="answered">Svarede ansøgninger</button>
      <button class="tab-btn" data-tab="player-info">Spiller info</button>
      <button class="tab-btn" data-tab="leaderboard">Leaderboard</button>
    </div>

    <div class="panel-intro" id="panelIntro">
      <h3>Vælg et område</h3>
      <p>Start med at vælge hvad du vil arbejde med, så åbner panelet.</p>
    </div>

    <div class="panel-grid">
      <div class="panel-card tab-panel" data-panel="staff">
        <h3>Staff</h3>
        <p>Synkroniserer staff-rollen fra Discord og lad jer redigere titler.</p>
        <?php if ($staffSyncStatus === "ok"): ?>
          <div class="notice success">Staff synkroniseret fra Discord.</div>
        <?php elseif ($staffSyncStatus === "fail"): ?>
          <div class="notice warning">Staff sync fejlede<?= $staffSyncError !== "" ? ": " . htmlspecialchars($staffSyncError) : "" ?>.</div>
        <?php endif; ?>
        <form action="sync_staff.php" method="post" class="rules-form">
          <button class="btn ghost" type="submit" name="force" value="1">Synkroniser fra Discord</button>
        </form>
        <?php if (empty($staffMembers)): ?>
          <div class="notice warning">Ingen staff fundet endnu. Tryk Synkroniser.</div>
        <?php else: ?>
          <?php foreach ($staffMembers as $member): ?>
            <?php
              $name = $member["display_name"] ?? ($member["username"] ?? "Staff");
              $avatarUrl = $member["avatar_url"] ?? "";
              $titleLine = $member["title"] ?? "";
              $rowClass = !empty($member["is_active"]) ? "staff-row" : "staff-row is-inactive";
            ?>
            <form action="update_staff.php" method="post" class="<?= $rowClass ?>">
              <input type="hidden" name="discord_user_id" value="<?= htmlspecialchars($member["discord_user_id"]) ?>" />
              <div class="staff-row-meta">
                <div class="staff-row-avatar">
                  <?php if ($avatarUrl): ?>
                    <img src="<?= htmlspecialchars($avatarUrl) ?>" alt="Discord avatar for <?= htmlspecialchars($name) ?>" />
                  <?php else: ?>
                    <?= htmlspecialchars(staff_initials($name)) ?>
                  <?php endif; ?>
                </div>
                <div>
                  <strong><?= htmlspecialchars($name) ?></strong>
                  <div class="muted">ID: <?= htmlspecialchars($member["discord_user_id"]) ?></div>
                  <?php if (empty($member["is_active"])): ?>
                    <div class="muted">Ikke i staff-rollen på Discord</div>
                  <?php endif; ?>
                </div>
              </div>
              <label class="field">
                <span>Rolle / titel</span>
                <input type="text" name="title" value="<?= htmlspecialchars($titleLine) ?>" placeholder="Stifter og Head Udvikler samtø'' Staff Management" />
              </label>
              <label class="field">
                <span>Sortering (højere = øverst)</span>
                <input type="number" name="sort_order" value="<?= (int) ($member["sort_order"] ?? 0) ?>" />
              </label>
              <div class="optin-actions">
                <button class="btn primary" type="submit">Gem</button>
              </div>
            </form>
          <?php endforeach; ?>
        <?php endif; ?>
      </div>
      <div class="panel-card tab-panel" data-panel="rules">
        <h3>Regler</h3>
        <p>Administrer regelkategorier og regler.</p>

        <div class="panel-sub">
          <h4>Kategorier</h4>
          <?php if (empty($ruleCategories)): ?>
            <div class="notice warning">Ingen regelkategorier endnu.</div>
          <?php else: ?>
            <?php foreach ($ruleCategories as $category): ?>
              <form action="save_rule_category.php" method="post" class="rules-form">
                <input type="hidden" name="id" value="<?= (int) $category["id"] ?>" />
                <label class="field">
                  <span>Navn</span>
                  <input type="text" name="name" value="<?= htmlspecialchars($category["name"]) ?>" required />
                </label>
                <label class="field">
                  <span>Sortering (højere = øverst)</span>
                  <input type="number" name="sort_order" value="<?= (int) ($category["sort_order"] ?? 0) ?>" />
                </label>
                <div class="rules-actions">
                  <button class="btn primary" type="submit">Gem kategori</button>
                  <button class="btn ghost danger" type="submit" formaction="delete_rule_category.php" formmethod="post" onclick="return confirm('Slet denne kategori?');">Slet kategori</button>
                </div>
              </form>
            <?php endforeach; ?>
          <?php endif; ?>

          <form action="save_rule_category.php" method="post" class="rules-form">
            <label class="field">
              <span>Ny kategori</span>
              <input type="text" name="name" required />
            </label>
            <label class="field">
              <span>Sortering (højere = øverst)</span>
              <input type="number" name="sort_order" value="0" />
            </label>
            <button class="btn ghost" type="submit">Tilføj kategori</button>
          </form>
        </div>

        <div class="panel-sub">
          <h4>Regler</h4>
          <?php if (empty($rules)): ?>
            <div class="notice warning">Ingen regler endnu.</div>
          <?php else: ?>
            <?php foreach ($rules as $rule): ?>
              <?php $ruleCategoryId = (int) ($rule["category_id"] ?? 0); ?>
              <form action="save_rules.php" method="post" class="rules-form">
                <input type="hidden" name="id" value="<?= (int) $rule["id"] ?>" />
                <label class="field">
                  <span>Kategori</span>
                  <select name="category_id">
                    <option value="">Uden kategori</option>
                    <?php foreach ($ruleCategories as $category): ?>
                      <option value="<?= (int) $category["id"] ?>" <?= $ruleCategoryId === (int) $category["id"] ? "selected" : "" ?>><?= htmlspecialchars($category["name"]) ?></option>
                    <?php endforeach; ?>
                  </select>
                </label>
                <label class="field">
                  <span>Titel</span>
                  <input type="text" name="title" value="<?= htmlspecialchars($rule["title"]) ?>" required />
                </label>
                <label class="field">
                  <span>Regel tekst</span>
                  <textarea name="body" rows="4" required><?= htmlspecialchars($rule["body"]) ?></textarea>
                </label>
                <div class="rules-actions">
                  <button class="btn primary" type="submit">Gem regel</button>
                  <button class="btn ghost danger" type="submit" formaction="delete_rule.php" formmethod="post" onclick="return confirm('Slet denne regel?');">Slet regel</button>
                </div>
              </form>
            <?php endforeach; ?>
          <?php endif; ?>

          <form action="save_rules.php" method="post" class="rules-form">
            <label class="field">
              <span>Kategori</span>
              <select name="category_id">
                <option value="">Uden kategori</option>
                <?php foreach ($ruleCategories as $category): ?>
                  <option value="<?= (int) $category["id"] ?>"><?= htmlspecialchars($category["name"]) ?></option>
                <?php endforeach; ?>
              </select>
            </label>
            <label class="field">
              <span>Ny titel</span>
              <input type="text" name="title" required />
            </label>
            <label class="field">
              <span>Ny regel tekst</span>
              <textarea name="body" rows="3" required></textarea>
            </label>
            <button class="btn ghost" type="submit">Tilføj ny regel</button>
          </form>
        </div>
      </div>

      <div class="panel-card tab-panel" data-panel="laws">
        <h3>Lovgivning</h3>
        <p>Administrer kategorier og lovpunkter.</p>

        <div class="panel-sub">
          <h4>Kategorier</h4>
          <?php if (empty($lawCategories)): ?>
            <div class="notice warning">Ingen lovkategorier endnu.</div>
          <?php else: ?>
            <?php foreach ($lawCategories as $category): ?>
              <form action="save_law_category.php" method="post" class="rules-form">
                <input type="hidden" name="id" value="<?= (int) $category["id"] ?>" />
                <label class="field">
                  <span>Navn</span>
                  <input type="text" name="name" value="<?= htmlspecialchars($category["name"]) ?>" required />
                </label>
                <label class="field">
                  <span>Sortering (højere = øverst)</span>
                  <input type="number" name="sort_order" value="<?= (int) ($category["sort_order"] ?? 0) ?>" />
                </label>
                <div class="rules-actions">
                  <button class="btn primary" type="submit">Gem kategori</button>
                  <button class="btn ghost danger" type="submit" formaction="delete_law_category.php" formmethod="post" onclick="return confirm('Slet denne kategori?');">Slet kategori</button>
                </div>
              </form>
            <?php endforeach; ?>
          <?php endif; ?>

          <form action="save_law_category.php" method="post" class="rules-form">
            <label class="field">
              <span>Ny kategori</span>
              <input type="text" name="name" required />
            </label>
            <label class="field">
              <span>Sortering (højere = øverst)</span>
              <input type="number" name="sort_order" value="0" />
            </label>
            <button class="btn ghost" type="submit">Tilføj kategori</button>
          </form>
        </div>

        <div class="panel-sub">
          <h4>Lovpunkter</h4>
          <?php if (empty($laws)): ?>
            <div class="notice warning">Ingen lovpunkter endnu.</div>
          <?php else: ?>
            <?php foreach ($laws as $law): ?>
              <?php $lawCategoryId = (int) ($law["category_id"] ?? 0); ?>
              <form action="save_law.php" method="post" class="rules-form">
                <input type="hidden" name="id" value="<?= (int) $law["id"] ?>" />
                <label class="field">
                  <span>Kategori</span>
                  <select name="category_id">
                    <option value="">Uden kategori</option>
                    <?php foreach ($lawCategories as $category): ?>
                      <option value="<?= (int) $category["id"] ?>" <?= $lawCategoryId === (int) $category["id"] ? "selected" : "" ?>><?= htmlspecialchars($category["name"]) ?></option>
                    <?php endforeach; ?>
                  </select>
                </label>
                <label class="field">
                  <span>Titel</span>
                  <input type="text" name="title" value="<?= htmlspecialchars($law["title"]) ?>" required />
                </label>
                <label class="field">
                  <span>Lov tekst</span>
                  <textarea name="body" rows="4" required><?= htmlspecialchars($law["body"]) ?></textarea>
                </label>
                <div class="rules-actions">
                  <button class="btn primary" type="submit">Gem lovpunkt</button>
                  <button class="btn ghost danger" type="submit" formaction="delete_law.php" formmethod="post" onclick="return confirm('Slet dette lovpunkt?');">Slet lovpunkt</button>
                </div>
              </form>
            <?php endforeach; ?>
          <?php endif; ?>

          <form action="save_law.php" method="post" class="rules-form">
            <label class="field">
              <span>Kategori</span>
              <select name="category_id">
                <option value="">Uden kategori</option>
                <?php foreach ($lawCategories as $category): ?>
                  <option value="<?= (int) $category["id"] ?>"><?= htmlspecialchars($category["name"]) ?></option>
                <?php endforeach; ?>
              </select>
            </label>
            <label class="field">
              <span>Ny titel</span>
              <input type="text" name="title" required />
            </label>
            <label class="field">
              <span>Ny lov tekst</span>
              <textarea name="body" rows="3" required></textarea>
            </label>
            <button class="btn ghost" type="submit">Tilføj lovpunkt</button>
          </form>
        </div>
      </div>

      <div class="panel-card tab-panel" data-panel="leaderboard">
        <h3>Donationer (Leaderboard)</h3>
        <p>Rediger visningsnavne eller anonymitet.</p>
        <?php if (empty($donors)): ?>
          <div class="notice warning">Ingen donationer endnu.</div>
        <?php else: ?>
          <?php foreach ($donors as $donor): ?>
            <form action="update_leaderboard.php" method="post" class="leaderboard-row">
              <input type="hidden" name="discord_user_id" value="<?= htmlspecialchars($donor["discord_user_id"]) ?>" />
              <div class="leaderboard-info">
                <strong><?= htmlspecialchars($donor["discord_user_id"]) ?></strong>
                <div class="leaderboard-meta">
                  <?php if (is_admin()): ?>
                    <details class="action-menu">
                      <summary class="btn ghost btn-icon" title="Admin handlinger">ðŸ”¨</summary>
                      <div class="menu-panel">
                        <button class="btn ghost" type="submit" name="opt_in" value="yes">Rediger</button>
                        <button class="btn ghost danger" type="submit" name="delete_user" value="1" formaction="delete_donation.php" formmethod="post" onclick="return confirm('Slet alle donationer for denne bruger?');">Slet donationer</button>
                      </div>
                    </details>
                  <?php endif; ?>
                  <span><?= number_format($donor["total"] / 100, 0, ",", ".") ?> DKK</span>
                </div>
              </div>
              <label class="field">
                <span>Nickname</span>
                <input type="text" name="nickname" value="<?= htmlspecialchars($donor["nickname"] ?? "") ?>" />
              </label>
              <div class="optin-actions">
                <button class="btn primary" type="submit" name="opt_in" value="yes">Vis</button>
                <button class="btn ghost" type="submit" name="opt_in" value="no">Anonym</button>
              </div>
            </form>
          <?php endforeach; ?>
        <?php endif; ?>
      </div>

      <div class="panel-card tab-panel" data-panel="applications">
        <h3>Ansøgninger</h3>
        <p>Se og administrer ansøgninger + skabeloner.</p>
        <div class="panel-sub">
          <h4>Ansøgningsskabeloner</h4>
          <?php if (empty($forms)): ?>
            <div class="notice warning">Ingen skabeloner endnu.</div>
          <?php endif; ?>
          <?php foreach ($forms as $form): ?>
            <?php
              $questionItems = preg_split("/\r\n|\r|\n/", (string) ($form["questions"] ?? ""));
              $questionItems = array_values(array_filter(array_map("trim", $questionItems), fn($q) => $q !== ""));
              if (empty($questionItems)) {
                $questionItems = [""];
              }
            ?>
            <form action="save_application_form.php" method="post" class="rules-form">
              <input type="hidden" name="id" value="<?= (int) $form["id"] ?>" />
              <label class="field">
                <span>Titel</span>
                <input type="text" name="title" value="<?= htmlspecialchars($form["title"]) ?>" required />
              </label>
              <label class="field">
                <span>Beskrivelse</span>
                <textarea name="description" rows="3" required><?= htmlspecialchars($form["description"]) ?></textarea>
              </label>
              <label class="field">
                <span>Spørgsmal</span>
                <div data-question-list>
                  <?php foreach ($questionItems as $questionItem): ?>
                    <div class="question-row">
                      <input type="text" name="questions[]" value="<?= htmlspecialchars($questionItem) ?>" required placeholder="Skriv spørgsmal..." />
                      <button class="btn ghost danger" type="button" data-remove-question>Fjern</button>
                    </div>
                  <?php endforeach; ?>
                </div>
                <button class="btn ghost" type="button" data-add-question>Tilføj spørgsmal</button>
              </label>
              <label class="field">
                <span>Webhook URL (valgfri)</span>
                <input type="url" name="webhook_url" value="<?= htmlspecialchars($form["webhook_url"] ?? "") ?>" placeholder="https://example.com/webhook" />
              </label>
              <label class="field">
                <span>Visibility</span>
                <select name="visibility">
                  <option value="public" <?= $form["visibility"] === "public" ? "selected" : "" ?>>Public</option>
                  <option value="whitelist" <?= $form["visibility"] === "whitelist" ? "selected" : "" ?>>Whitelist</option>
                </select>
              </label>
              <label class="field">
                <span>Type (slug)</span>
                <input type="text" name="type" value="<?= htmlspecialchars($form["type"]) ?>" required />
              </label>
              <button class="btn primary" type="submit">Gem skabelon</button>
            </form>
          <?php endforeach; ?>

          <form action="save_application_form.php" method="post" class="rules-form">
            <label class="field">
              <span>Ny titel</span>
              <input type="text" name="title" required />
            </label>
            <label class="field">
              <span>Ny beskrivelse</span>
              <textarea name="description" rows="3" required></textarea>
            </label>
            <label class="field">
              <span>Spørgsmal</span>
              <div data-question-list>
                <div class="question-row">
                  <input type="text" name="questions[]" required placeholder="Skriv spørgsmal..." />
                  <button class="btn ghost danger" type="button" data-remove-question>Fjern</button>
                </div>
              </div>
              <button class="btn ghost" type="button" data-add-question>Tilføj spørgsmal</button>
            </label>
            <label class="field">
              <span>Webhook URL (valgfri)</span>
              <input type="url" name="webhook_url" placeholder="https://example.com/webhook" />
            </label>
            <label class="field">
              <span>Visibility</span>
              <select name="visibility">
                <option value="public">Public</option>
                <option value="whitelist">Whitelist</option>
              </select>
            </label>
            <label class="field">
              <span>Type (slug)</span>
              <input type="text" name="type" required />
            </label>
            <button class="btn ghost" type="submit">Tilføj skabelon</button>
          </form>
        </div>

      </div>

      <div class="panel-card tab-panel" data-panel="submissions">
        <h3>Sendte ansøgninger</h3>
        <p>Se indhold og godkend/afvis.</p>
        <div class="filter-bar">
          <input type="text" class="filter-input" placeholder="Søg på navn, type eller indhold..." />
          <select class="filter-select" style="background:#3a3d44;color:#ffffff;border:1px solid rgba(165,170,186,.35);">
            <option value="all" style="background:#3a3d44;color:#ffffff;">Alle status</option>
            <option value="pending" selected style="background:#3a3d44;color:#ffffff;">Afventer</option>
            <option value="approved" style="background:#3a3d44;color:#ffffff;">Godkendt</option>
            <option value="denied" style="background:#3a3d44;color:#ffffff;">Afvist</option>
          </select>
        </div>
        <?php if (empty($applications)): ?>
          <div class="notice warning">Ingen ansøgninger endnu.</div>
        <?php else: ?>
          <?php foreach ($applications as $app): ?>
            <?php
              $contentText = $app["content"] ?? "";
              $decoded = json_decode($contentText, true);
              if (is_array($decoded) && isset($decoded["answers"])) {
                $contentText = implode("\n", array_map("trim", $decoded["answers"]));
              }
              $searchText = strtolower(
                trim(($app["title"] ?? $app["type"]) . " " . $app["applicant_name"] . " " . $contentText)
              );
            ?>
            <form action="update_application.php" method="post" class="application-row" data-status="<?= htmlspecialchars($app["status"]) ?>" data-search="<?= htmlspecialchars($searchText) ?>">
              <input type="hidden" name="id" value="<?= (int) $app["id"] ?>" />
              <div>
                <strong><?= htmlspecialchars($app["title"] ?? $app["type"]) ?></strong>
                <div class="muted"><?= htmlspecialchars($app["applicant_name"]) ?></div>
                <div class="muted"><?= htmlspecialchars($app["created_at"]) ?></div>
              </div>
              <label class="field">
                <span>Indhold</span>
                <textarea name="content" rows="5"><?= htmlspecialchars($contentText) ?></textarea>
              </label>
              <label class="field">
                <span>Staff svar</span>
                <textarea name="staff_response" rows="3"><?= htmlspecialchars($app["staff_response"] ?? "") ?></textarea>
              </label>
              <div class="optin-actions">
                <button class="btn primary" type="submit" name="status" value="approved">Godkend</button>
                <button class="btn ghost" type="submit" name="status" value="denied">Afvis</button>
                <button class="btn ghost" type="submit" name="status" value="pending">Afventer</button>
              </div>
            </form>
          <?php endforeach; ?>
        <?php endif; ?>
      </div>

      <div class="panel-card tab-panel" data-panel="answered">
        <h3>Svarede ansøgninger</h3>
        <p>Ansøgninger der er godkendt eller afvist.</p>
        <?php if ($applicationDeletedStatus === "1"): ?>
          <div class="notice success">Ansøgningen blev fjernet fra aktiv liste.</div>
        <?php elseif ($applicationDeletedStatus === "0"): ?>
          <div class="notice warning">Kunne ikke fjerne ansøgningen.</div>
        <?php endif; ?>
        <div class="filter-bar">
          <input type="text" class="filter-input answered-input" placeholder="Søg på navn, type eller indhold..." />
          <select class="filter-select answered-select" style="background:#3a3d44;color:#ffffff;border:1px solid rgba(165,170,186,.35);">
            <option value="approved" style="background:#3a3d44;color:#ffffff;">Godkendt</option>
            <option value="denied" style="background:#3a3d44;color:#ffffff;">Afvist</option>
            <option value="all" style="background:#3a3d44;color:#ffffff;">Alle svar</option>
          </select>
        </div>
        <?php if (empty($applications)): ?>
          <div class="notice warning">Ingen ansøgninger endnu.</div>
        <?php else: ?>
          <?php foreach ($applications as $app): ?>
            <?php
              if ($app["status"] === "pending") { continue; }
              $contentText = $app["content"] ?? "";
              $decoded = json_decode($contentText, true);
              if (is_array($decoded) && isset($decoded["answers"])) {
                $contentText = implode("\n", array_map("trim", $decoded["answers"]));
              }
              $searchText = strtolower(
                trim(($app["title"] ?? $app["type"]) . " " . $app["applicant_name"] . " " . $contentText)
              );
            ?>
            <form action="update_application.php" method="post" class="application-row answered-row" data-status="<?= htmlspecialchars($app["status"]) ?>" data-search="<?= htmlspecialchars($searchText) ?>">
              <input type="hidden" name="id" value="<?= (int) $app["id"] ?>" />
              <div>
                <strong><?= htmlspecialchars($app["title"] ?? $app["type"]) ?></strong>
                <div class="muted"><?= htmlspecialchars($app["applicant_name"]) ?></div>
                <div class="muted"><?= htmlspecialchars($app["created_at"]) ?></div>
              </div>
              <label class="field">
                <span>Indhold</span>
                <textarea name="content" rows="5"><?= htmlspecialchars($contentText) ?></textarea>
              </label>
              <label class="field">
                <span>Staff svar</span>
                <textarea name="staff_response" rows="3"><?= htmlspecialchars($app["staff_response"] ?? "") ?></textarea>
              </label>
              <div class="optin-actions">
                <button class="btn ghost" type="submit" name="status" value="pending">Tilbage til afventer</button>
                <button class="btn ghost danger" type="submit" formaction="delete_application.php" formmethod="post" onclick="return confirm('Fjern denne ansøgning fra aktiv liste?');">Fjern manuelt</button>
              </div>
            </form>
          <?php endforeach; ?>
        <?php endif; ?>
      </div>

      <div class="panel-card tab-panel" data-panel="player-info">
        <h3>Spiller info</h3>
        <p>Søg på Discord ID og se ansøgningsstatistik samt detaljer.</p>
        <form action="staff_panel.php" method="get" class="rules-form">
          <input type="hidden" name="tab" value="player-info" />
          <label class="field">
            <span>Discord ID</span>
            <input type="text" name="player_discord_id" value="<?= htmlspecialchars($playerDiscordId) ?>" placeholder="fx 123456789012345678" required />
          </label>
          <button class="btn primary" type="submit">Hent spiller info</button>
        </form>

        <?php if ($playerDiscordId !== "" && $playerLookup && (int) $playerLookup["counts"]["total"] === 0): ?>
          <div class="notice warning">Ingen data fundet for den Discord ID.</div>
        <?php elseif ($playerLookup): ?>
          <div class="player-stats-grid">
            <article class="player-stat">
              <span>Total</span>
              <strong><?= (int) $playerLookup["counts"]["total"] ?></strong>
            </article>
            <article class="player-stat">
              <span>Afventer</span>
              <strong><?= (int) $playerLookup["counts"]["pending"] ?></strong>
            </article>
            <article class="player-stat">
              <span>Godkendt</span>
              <strong><?= (int) $playerLookup["counts"]["approved"] ?></strong>
            </article>
            <article class="player-stat">
              <span>Afvist</span>
              <strong><?= (int) $playerLookup["counts"]["denied"] ?></strong>
            </article>
          </div>

          <div class="panel-sub">
            <h4>Fordeling pa typer</h4>
            <?php if (empty($playerLookup["by_type"])): ?>
              <div class="notice warning">Ingen typer fundet.</div>
            <?php else: ?>
              <div class="player-type-list">
                <?php foreach ($playerLookup["by_type"] as $typeLabel => $count): ?>
                  <div class="player-type-item">
                    <strong><?= htmlspecialchars((string) $typeLabel) ?></strong>
                    <span><?= (int) $count ?> ansøgninger</span>
                  </div>
                <?php endforeach; ?>
              </div>
            <?php endif; ?>
          </div>

          <div class="panel-sub">
            <h4>Ansøgningshistorik</h4>
            <?php if (empty($playerLookup["applications"])): ?>
              <div class="notice warning">Ingen ansøgninger fundet.</div>
            <?php else: ?>
              <?php foreach ($playerLookup["applications"] as $app): ?>
                <?php
                  $contentText = (string) ($app["content"] ?? "");
                  $decoded = json_decode($contentText, true);
                  if (is_array($decoded) && isset($decoded["answers"]) && is_array($decoded["answers"])) {
                    $contentText = implode("\n", array_map("trim", $decoded["answers"]));
                  }
                ?>
                <article class="application-row">
                  <div>
                    <strong><?= htmlspecialchars((string) (($app["form_title"] ?? "") !== "" ? $app["form_title"] : ($app["type"] ?? "Ukendt"))) ?></strong>
                    <div class="muted">Status: <?= htmlspecialchars((string) ($app["status"] ?? "pending")) ?></div>
                    <div class="muted">Oprettet: <?= htmlspecialchars((string) ($app["created_at"] ?? "")) ?></div>
                    <?php if (!empty($app["answered_at"])): ?>
                      <div class="muted">Besvaret: <?= htmlspecialchars((string) $app["answered_at"]) ?></div>
                    <?php endif; ?>
                    <?php if (($app["source"] ?? "active") === "history"): ?>
                      <div class="muted">Kilde: Historik</div>
                    <?php endif; ?>
                  </div>
                  <?php if ($contentText !== ""): ?>
                    <label class="field">
                      <span>Indhold</span>
                      <textarea rows="4" readonly><?= htmlspecialchars($contentText) ?></textarea>
                    </label>
                  <?php endif; ?>
                  <?php if (!empty($app["staff_response"])): ?>
                    <label class="field">
                      <span>Staff svar</span>
                      <textarea rows="3" readonly><?= htmlspecialchars((string) $app["staff_response"]) ?></textarea>
                    </label>
                  <?php endif; ?>
                </article>
              <?php endforeach; ?>
            <?php endif; ?>
          </div>
        <?php endif; ?>
      </div>
    </div>
  </section>
</main>

<?php
require_once __DIR__ . "/includes/footer.php";
?>
<script>
  const tabButtons = document.querySelectorAll(".tab-btn");
  const tabPanels = document.querySelectorAll(".tab-panel");
  const panelIntro = document.getElementById("panelIntro");
  const filterInput = document.querySelector(".filter-input");
  const filterSelect = document.querySelector(".filter-select");
  const answeredInput = document.querySelector(".answered-input");
  const answeredSelect = document.querySelector(".answered-select");
  const initialTab = new URLSearchParams(window.location.search).get("tab");

  function activateTab(target) {
    if (!target) {
      return;
    }
    let found = false;
    tabButtons.forEach((b) => {
      const isTarget = b.getAttribute("data-tab") === target;
      b.classList.toggle("is-active", isTarget);
      if (isTarget) {
        found = true;
      }
    });
    tabPanels.forEach((panel) => {
      panel.classList.toggle("is-active", panel.getAttribute("data-panel") === target);
    });
    if (found && panelIntro) {
      panelIntro.classList.add("hidden");
    }
  }

  tabButtons.forEach((btn) => {
    btn.addEventListener("click", () => {
      activateTab(btn.getAttribute("data-tab"));
    });
  });

  function createQuestionRow(value = "") {
    const row = document.createElement("div");
    row.className = "question-row";
    row.innerHTML = `
      <input type="text" name="questions[]" required placeholder="Skriv spørgsmal..." />
      <button class="btn ghost danger" type="button" data-remove-question>Fjern</button>
    `;
    const input = row.querySelector('input[name="questions[]"]');
    if (input) {
      input.value = value;
    }
    return row;
  }

  function ensureQuestionRows(questionList) {
    const rows = questionList.querySelectorAll(".question-row");
    if (rows.length === 0) {
      questionList.appendChild(createQuestionRow(""));
    }
  }

  document.querySelectorAll("[data-question-list]").forEach((questionList) => {
    ensureQuestionRows(questionList);
  });

  document.querySelectorAll("[data-add-question]").forEach((button) => {
    button.addEventListener("click", () => {
      const form = button.closest("form");
      const questionList = form?.querySelector("[data-question-list]");
      if (!questionList) {
        return;
      }
      questionList.appendChild(createQuestionRow(""));
      ensureQuestionRows(questionList);
    });
  });

  document.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof HTMLElement) || !target.matches("[data-remove-question]")) {
      return;
    }
    const row = target.closest(".question-row");
    const questionList = target.closest("form")?.querySelector("[data-question-list]");
    if (!row || !questionList) {
      return;
    }
    const rowCount = questionList.querySelectorAll(".question-row").length;
    if (rowCount <= 1) {
      const input = row.querySelector('input[name="questions[]"]');
      if (input) {
        input.value = "";
        input.focus();
      }
      return;
    }
    row.remove();
    ensureQuestionRows(questionList);
  });

  function applyFilters() {
    const query = (filterInput?.value || "").toLowerCase().trim();
    const status = filterSelect?.value || "pending";
    const rows = document.querySelectorAll(".application-row:not(.answered-row)");
    rows.forEach((row) => {
      const rowStatus = row.getAttribute("data-status") || "";
      const rowSearch = row.getAttribute("data-search") || "";
      const matchesStatus = status === "all" || rowStatus === status;
      const matchesSearch = query === "" || rowSearch.includes(query);
      row.style.display = matchesStatus && matchesSearch ? "grid" : "none";
    });
  }

  function applyAnsweredFilters() {
    const query = (answeredInput?.value || "").toLowerCase().trim();
    const status = answeredSelect?.value || "approved";
    const rows = document.querySelectorAll(".answered-row");
    rows.forEach((row) => {
      const rowStatus = row.getAttribute("data-status") || "";
      const rowSearch = row.getAttribute("data-search") || "";
      const matchesStatus = status === "all" || rowStatus === status;
      const matchesSearch = query === "" || rowSearch.includes(query);
      row.style.display = matchesStatus && matchesSearch ? "grid" : "none";
    });
  }

  if (filterInput) {
    filterInput.addEventListener("input", applyFilters);
  }
  if (filterSelect) {
    filterSelect.addEventListener("change", applyFilters);
  }

  if (answeredInput) {
    answeredInput.addEventListener("input", applyAnsweredFilters);
  }
  if (answeredSelect) {
    answeredSelect.addEventListener("change", applyAnsweredFilters);
  }

  applyFilters();
  applyAnsweredFilters();
  if (initialTab) {
    activateTab(initialTab);
  }
</script>


