<?php
require_once __DIR__ . "/includes/header.php";
require_once __DIR__ . "/includes/db.php";

if (!is_logged_in()) {
    header("Location: login.php");
    exit;
}

$formId = (int) ($_GET["form_id"] ?? 0);
if ($formId <= 0) {
    header("Location: applications.php");
    exit;
}

$formRows = db_fetch_all("SELECT id, title, description, questions, visibility FROM application_forms WHERE id = ? LIMIT 1", [$formId]);
$form = $formRows[0] ?? null;

if (!$form) {
    header("Location: applications.php");
    exit;
}

if ($form["visibility"] === "whitelist" && !(is_whitelisted() || is_staff() || is_admin())) {
    http_response_code(403);
    echo "Ingen adgang";
    exit;
}

$questions = array_filter(array_map("trim", explode("\n", $form["questions"])));
?>

<main>
  <section class="applications-page">
    <div class="section-heading">
      <h2><?= htmlspecialchars($form["title"]) ?></h2>
      <p><?= htmlspecialchars($form["description"]) ?></p>
    </div>

    <form action="create_application.php" method="post" class="panel-card">
      <input type="hidden" name="form_id" value="<?= (int) $form["id"] ?>" />
      <?php if (empty($questions)): ?>
        <label class="field">
          <span>Din ansøgning</span>
          <textarea name="content[]" rows="6" required placeholder="Skriv din ansøgning her..."></textarea>
        </label>
      <?php else: ?>
        <?php foreach ($questions as $index => $question): ?>
          <label class="field">
            <span><?= htmlspecialchars($question) ?></span>
            <textarea name="content[]" rows="4" required></textarea>
          </label>
        <?php endforeach; ?>
      <?php endif; ?>
      <button class="btn primary" type="submit">Send ansøgning</button>
    </form>
  </section>
</main>

<?php
require_once __DIR__ . "/includes/footer.php";
?>
