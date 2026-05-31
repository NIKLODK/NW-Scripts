<?php
require_once __DIR__ . "/includes/header.php";
require_once __DIR__ . "/includes/db.php";
require_once __DIR__ . "/includes/application_lifecycle.php";

if (!is_logged_in()) {
    header("Location: login.php");
    exit;
}

$loggedIn = true;
$whitelisted = is_whitelisted();
$staff = is_staff();
$admin = is_admin();
$deletedNotice = isset($_GET["deleted"]);
$deleteErrorNotice = isset($_GET["delete_error"]);

application_cleanup_answered(3);

// Application forms are created by staff
$forms = db_fetch_all("SELECT id, title, description, visibility FROM application_forms ORDER BY created_at ASC");

$user = discord_user();
$userId = $user["id"] ?? null;
$myApplications = [];
if ($userId) {
    $myApplications = db_fetch_all(
        "SELECT a.id, a.status, a.created_at, a.staff_response, f.title
         FROM applications a
         LEFT JOIN application_forms f ON f.id = a.form_id
         WHERE a.discord_user_id = ?
         ORDER BY (a.status = 'approved') DESC, a.created_at DESC",
        [$userId]
    );
    db_execute(
        "UPDATE applications SET notified = 1 WHERE discord_user_id = ? AND status IN ('approved','denied') AND notified = 0",
        [$userId]
    );
}
?>

  <main>
    <section class="applications-page">
      <div class="section-heading">
        <h2>Ansøgninger</h2>
        <p>Du skal være logget ind med Discord for at se ansøgninger.</p>
      </div>

      <?php if (!$loggedIn): ?>
        <div class="notice warning">
          Log ind for at se ansøgninger.
        </div>
        <a class="btn primary" href="login.php">Log ind med Discord</a>
      <?php else: ?>
        <?php if ($deletedNotice): ?>
          <div class="notice success">Ansøgningen blev fjernet.</div>
        <?php elseif ($deleteErrorNotice): ?>
          <div class="notice warning">Kunne ikke fjerne ansøgningen. Prøv igen.</div>
        <?php endif; ?>
        <div class="notice success">
          <?= ($whitelisted || $staff || $admin)
            ? "Du har adgang til alle ansøgninger."
            : "Du er logget ind. Kun whitelist og unban ansøgninger vises."; ?>
        </div>
        <div class="applications-grid">
          <?php if (empty($forms)): ?>
            <div class="notice warning">Der er ingen ansøgningsskabeloner endnu. Staff skal oprette dem.</div>
          <?php else: ?>
            <?php foreach ($forms as $form): ?>
              <?php if ($form["visibility"] === "whitelist" && !($whitelisted || $staff || $admin)) { continue; } ?>
              <article class="app-card">
                <h3><?= htmlspecialchars($form["title"]) ?></h3>
                <p><?= htmlspecialchars($form["description"]) ?></p>
                <a class="btn ghost" href="apply.php?form_id=<?= (int) $form["id"] ?>">Opret</a>
              </article>
            <?php endforeach; ?>
          <?php endif; ?>
        </div>

        <section class="applications-list">
          <div class="section-heading">
            <h3>Dine ansøgninger</h3>
          </div>
          <?php if (empty($myApplications)): ?>
            <div class="notice warning">Du har ingen ansøgninger endnu.</div>
          <?php else: ?>
            <div class="applications-grid">
              <?php foreach ($myApplications as $appRow): ?>
                <article class="app-card" id="application-<?= (int) $appRow["id"] ?>">
                  <h3><?= htmlspecialchars($appRow["title"] ?? "Ansøgning") ?></h3>
                  <p>Status: <?= htmlspecialchars($appRow["status"]) ?></p>
                  <p><?= htmlspecialchars($appRow["created_at"]) ?></p>
                  <?php if (!empty($appRow["staff_response"])): ?>
                    <p><strong>Staff svar:</strong> <?= htmlspecialchars($appRow["staff_response"]) ?></p>
                  <?php endif; ?>
                  <?php if (in_array($appRow["status"], ["approved", "denied"], true)): ?>
                    <form action="delete_application.php" method="post" onsubmit="return confirm('Fjerne denne ansøgning fra listen?');">
                      <input type="hidden" name="id" value="<?= (int) $appRow["id"] ?>" />
                      <button class="btn ghost danger" type="submit">Fjern manuelt</button>
                    </form>
                  <?php endif; ?>
                </article>
              <?php endforeach; ?>
            </div>
          <?php endif; ?>
        </section>
      <?php endif; ?>
    </section>
  </main>

<?php
require_once __DIR__ . "/includes/footer.php";
?>
