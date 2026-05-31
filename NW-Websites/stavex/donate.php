<?php
require_once __DIR__ . "/includes/header.php";
require_once __DIR__ . "/includes/db.php";

if (!is_logged_in()) {
    header("Location: login.php");
    exit;
}

$totalRow = db_fetch_all("SELECT COALESCE(SUM(amount), 0) AS total FROM donations");
$totalAmount = (int) ($totalRow[0]["total"] ?? 0);
$goalAmount = DONATION_GOAL_AMOUNT * 100;
$progress = $goalAmount > 0 ? min(100, ($totalAmount / $goalAmount) * 100) : 0;

$topDonors = db_fetch_all(
    "SELECT
        COALESCE(d.discord_user_id, CONCAT('name:', d.discord_name), CONCAT('id:', d.id)) AS donor_key,
        d.discord_user_id,
        SUM(d.amount) AS total,
        l.nickname,
        l.opted_in
     FROM donations d
     LEFT JOIN leaderboard_optin l ON l.discord_user_id = d.discord_user_id
     GROUP BY donor_key, d.discord_user_id, l.nickname, l.opted_in
     ORDER BY total DESC
     LIMIT 10"
);

$status = $_GET["status"] ?? null;
$saved = ($_GET["saved"] ?? "") === "1";
$error = $_GET["error"] ?? null;
$currentUser = discord_user();
$currentUserId = $currentUser["id"] ?? null;
$currentOpt = null;

if ($currentUserId) {
    $optRows = db_fetch_all(
        "SELECT nickname, opted_in FROM leaderboard_optin WHERE discord_user_id = ? LIMIT 1",
        [$currentUserId]
    );
    $currentOpt = $optRows[0] ?? null;
}
?>

  <main>
    <section class="donation-hero">
      <div>
        <p class="eyebrow">Støt serveren</p>
        <h1>Donationer holder StavexRP kørende.</h1>
        <p>
          Alle donationer går til server drift, udvikling og events. Tak for din støtte!
        </p>
        <div class="goal-card">
          <div>
            <strong>Donation Goal</strong>
            <p class="goal-amount">
              <?= number_format($totalAmount / 100, 0, ",", ".") ?> DKK / <?= number_format(DONATION_GOAL_AMOUNT, 0, ",", ".") ?> DKK
            </p>
          </div>
          <div class="progress">
            <div class="progress-bar" style="width: <?= round($progress, 2) ?>%"></div>
          </div>
          <span class="goal-note">Næste mål: nyt ressourcesystem</span>
        </div>
      </div>
      <div class="donate-panel">
        <h2>Donér nu</h2>
        <p>Guld medlem: 75 kr / måned. Betaling sker via Stripe.</p>
        <?php if (!is_logged_in()): ?>
          <div class="notice warning">
            Log ind med Discord før betaling for at få Guld badge på profilen.
          </div>
          <a class="btn primary full" href="login.php">Log ind med Discord</a>
        <?php else: ?>
          <form action="create_checkout_session.php" method="post">
            <label class="field">
              <span>Discord navn (valgfri)</span>
              <input type="text" name="discord_name" placeholder="Navn#0000" />
            </label>
            <button class="btn primary full" type="submit">Gå til betaling</button>
          </form>
          <p class="note">Du bliver sendt direkte til Stripe Checkout.</p>
        <?php endif; ?>
      </div>
    </section>

    <?php if ($status === "success"): ?>
      <section class="post-purchase">
        <div class="post-card">
          <div class="section-heading">
            <h2>Tak for dit køb</h2>
            <p>Vil du med på leaderboard? Hvis ja, skriv dit nickname.</p>
          </div>

          <?php if (!is_logged_in()): ?>
            <div class="notice warning">
              Log ind med Discord for at knytte Guld medlemskab og leaderboard til din profil.
            </div>
            <a class="btn primary" href="login.php">Log ind med Discord</a>
          <?php else: ?>
            <?php if ($saved): ?>
              <div class="notice success">Dine leaderboard-indstillinger er gemt.</div>
            <?php endif; ?>
            <?php if ($error === "nickname"): ?>
              <div class="notice warning">Skriv et nickname, hvis du vil være på leaderboard.</div>
            <?php endif; ?>

            <form action="leaderboard_optin.php" method="post" class="leaderboard-form">
              <label class="field">
                <span>Nickname (vises kun hvis du vælger Ja)</span>
                <input type="text" name="nickname" value="<?= htmlspecialchars($currentOpt["nickname"] ?? "") ?>" />
              </label>
              <div class="optin-actions">
                <button class="btn primary btn-lg" type="submit" name="opt_in" value="yes">Ja, vis mig</button>
                <button class="btn ghost btn-lg" type="submit" name="opt_in" value="no">Nej, hold mig anonym</button>
              </div>
            </form>
          <?php endif; ?>
        </div>
      </section>
    <?php endif; ?>

    <section class="top-donors">
      <div class="section-heading">
        <h2>Top 10 donators</h2>
        <p>Tak til de spillere der gør en forskel.</p>
      </div>
      <div class="donor-list">
        <?php if (empty($topDonors)): ?>
          <div class="donor-item">
            <span>#</span>
            <strong>Ingen donationer endnu</strong>
            <span>0 DKK</span>
          </div>
        <?php else: ?>
          <?php foreach ($topDonors as $index => $donor): ?>
            <div class="donor-item">
              <span>#<?= $index + 1 ?></span>
              <strong>
                <?php
                  $showName = ($donor["opted_in"] ?? 0) && !empty($donor["nickname"]);
                  echo htmlspecialchars($showName ? $donor["nickname"] : "Anonym");
                ?>
              </strong>
              <span><?= number_format($donor["total"] / 100, 0, ",", ".") ?> DKK</span>
            </div>
          <?php endforeach; ?>
        <?php endif; ?>
      </div>
    </section>
  </main>

<?php
require_once __DIR__ . "/includes/footer.php";
?>
