<?php
require_once __DIR__ . "/includes/header.php";
require_once __DIR__ . "/includes/db.php";

$rulesRows = db_fetch_all(
    "SELECT r.id, r.title, r.body, r.category_id, rc.name AS category_name, rc.sort_order AS category_sort
     FROM rules r
     LEFT JOIN rule_categories rc ON rc.id = r.category_id
     ORDER BY
       CASE WHEN rc.id IS NULL THEN 1 ELSE 0 END,
       rc.sort_order DESC,
       rc.name ASC,
       r.id ASC"
);

$groupedRules = [];
foreach ($rulesRows as $rule) {
    $categoryId = (int) ($rule["category_id"] ?? 0);
    $categoryKey = $categoryId > 0 ? (string) $categoryId : "general";
    $categoryName = trim((string) ($rule["category_name"] ?? ""));
    if ($categoryName === "") {
        $categoryName = "Generelle regler";
    }

    if (!isset($groupedRules[$categoryKey])) {
        $groupedRules[$categoryKey] = [
            "name" => $categoryName,
            "items" => [],
        ];
    }

    $groupedRules[$categoryKey]["items"][] = $rule;
}
?>

<main>
  <section class="rules-page">
    <div class="section-heading">
      <h2>Regler</h2>
      <p>For at sikre den bedst mulige oplevelse for alle spillere, skal reglerne overholdes. Brud kan medføre advarsel, kick eller ban.</p>
    </div>

    <?php if (empty($rulesRows)): ?>
      <div class="rules-grid">
        <article class="rule-card">
          <h3>Respekt og RP</h3>
          <p>Vis respekt for andre spillere og hold RP realistisk.</p>
        </article>
        <article class="rule-card">
          <h3>Ingen powergaming</h3>
          <p>Undgaa handlinger der er urealistiske eller ødelaegger andres RP.</p>
        </article>
        <article class="rule-card">
          <h3>Ingen metagaming</h3>
          <p>Brug ikke information din karakter ikke har adgang til.</p>
        </article>
      </div>
    <?php else: ?>
      <div class="rules-categories">
        <?php foreach ($groupedRules as $group): ?>
          <section class="rules-category">
            <h3><?= htmlspecialchars($group["name"]) ?></h3>
            <div class="rules-grid">
              <?php foreach ($group["items"] as $rule): ?>
                <article class="rule-card">
                  <h4><?= htmlspecialchars($rule["title"]) ?></h4>
                  <p><?= nl2br(htmlspecialchars($rule["body"])) ?></p>
                </article>
              <?php endforeach; ?>
            </div>
          </section>
        <?php endforeach; ?>
      </div>
    <?php endif; ?>
  </section>
</main>

<?php
require_once __DIR__ . "/includes/footer.php";
?>
