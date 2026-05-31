<?php
require_once __DIR__ . "/includes/header.php";
require_once __DIR__ . "/includes/db.php";

$lawsRows = db_fetch_all(
    "SELECT l.id, l.title, l.body, l.category_id, lc.name AS category_name, lc.sort_order AS category_sort
     FROM laws l
     LEFT JOIN law_categories lc ON lc.id = l.category_id
     ORDER BY
       CASE WHEN lc.id IS NULL THEN 1 ELSE 0 END,
       lc.sort_order DESC,
       lc.name ASC,
       l.id ASC"
);

$groupedLaws = [];
foreach ($lawsRows as $law) {
    $categoryId = (int) ($law["category_id"] ?? 0);
    $categoryKey = $categoryId > 0 ? (string) $categoryId : "general";
    $categoryName = trim((string) ($law["category_name"] ?? ""));
    if ($categoryName === "") {
        $categoryName = "Generel lovgivning";
    }

    if (!isset($groupedLaws[$categoryKey])) {
        $groupedLaws[$categoryKey] = [
            "name" => $categoryName,
            "items" => [],
        ];
    }

    $groupedLaws[$categoryKey]["items"][] = $law;
}
?>

<main>
  <section class="rules-page legislation-page">
    <div class="section-heading">
      <h2>Lovgivning</h2>
      <p>Samlet overblik over lovgivning fordelt paa kategorier.</p>
    </div>

    <?php if (empty($lawsRows)): ?>
      <div class="rules-grid">
        <article class="rule-card">
          <h3>Ingen lovgivning endnu</h3>
          <p>Staff kan oprette kategorier og lovpunkter i staff panelet.</p>
        </article>
      </div>
    <?php else: ?>
      <div class="rules-categories">
        <?php foreach ($groupedLaws as $group): ?>
          <section class="rules-category">
            <h3><?= htmlspecialchars($group["name"]) ?></h3>
            <div class="rules-grid">
              <?php foreach ($group["items"] as $law): ?>
                <article class="rule-card">
                  <h4><?= htmlspecialchars($law["title"]) ?></h4>
                  <p><?= nl2br(htmlspecialchars($law["body"])) ?></p>
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
