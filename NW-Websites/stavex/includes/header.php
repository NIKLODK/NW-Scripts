<?php
require_once __DIR__ . "/auth.php";
require_once __DIR__ . "/db.php";
$user = discord_user();
$loggedIn = is_logged_in();
$whitelisted = is_whitelisted();
$staff = is_staff();
$admin = is_admin();
$isGold = false;
$notificationCount = 0;
$basePath = "";
$logoPath = "";
$logoSrc = "";

if (isset($_SERVER["SCRIPT_NAME"])) {
  $basePath = rtrim(str_replace("\\", "/", dirname($_SERVER["SCRIPT_NAME"])), "/");
}

$logoPath = $basePath . "/images/logo.png";
$logoFile = __DIR__ . "/../images/logo.png";
$logoVersion = file_exists($logoFile) ? filemtime($logoFile) : null;
$logoSrc = $logoVersion ? ($logoPath . "?v=" . $logoVersion) : $logoPath;

if ($loggedIn && !empty($user["id"])) {
  $rows = db_fetch_all(
    "SELECT 1 FROM donations WHERE discord_user_id = ? LIMIT 1",
    [$user["id"]]
  );
  $isGold = !empty($rows);

  $notifRows = db_fetch_all(
    "SELECT COUNT(*) AS total FROM applications WHERE discord_user_id = ? AND status IN ('approved','denied') AND notified = 0",
    [$user["id"]]
  );
  $notificationCount = (int) ($notifRows[0]["total"] ?? 0);
}
?>
<!doctype html>
<html lang="da">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title><?= htmlspecialchars(SITE_NAME) ?></title>
  <link rel="stylesheet" href="<?= $basePath ?>/styles.css" />
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=Space+Grotesk:wght@400;500;600;700&family=Playfair+Display:wght@600;700&display=swap" rel="stylesheet" />
  <link rel="icon" type="image/png" href="<?= $logoSrc ?>" />
</head>
<body>
  <header class="site-header">
    <div class="brand">
      <img class="brand-logo" src="<?= $logoSrc ?>" width="50" height="50" alt="StavexRP logo">
      <div class="brand-text">
        <strong>StavexRP</strong>
        <span>FiveM • Dansk RP</span>
      </div>
    </div>
    <nav class="site-nav">
      <a href="<?= $basePath ?>/#hjem">HJEM</a>
      <a href="<?= $basePath ?>/#staff">STAFF</a>
      <a href="<?= $basePath ?>/rules.php">REGLER</a>
      <a href="<?= $basePath ?>/lovgivning.php">LOVGIVNING</a>
      <a href="<?= $basePath ?>/applications.php">ANSØGNINGER</a>
      <!-- <a href="<?= $basePath ?>/donate.php">DONATION</a> -->
      <?php if ($staff || $admin): ?>
        <a href="<?= $basePath ?>/staff_panel.php">STAFF PANEL</a>
      <?php endif; ?>
    </nav>
    <div class="auth-area">
      <?php if ($loggedIn): ?>
        <div class="user-chip">
          <span><?= htmlspecialchars($user["username"] ?? "Discord") ?></span>
          <a class="bell" href="<?= $basePath ?>/applications.php" title="Notifikationer">
            <span>🔔</span>
            <?php if ($notificationCount > 0): ?>
              <span class="bell-dot"></span>
            <?php endif; ?>
          </a>
          <?php if ($isGold): ?>
            <span class="chip-badge gold">Guld</span>
          <?php endif; ?>
          <?php if ($admin): ?>
            <span class="chip-badge">Admin</span>
          <?php elseif ($staff): ?>
            <span class="chip-badge">Staff</span>
          <?php elseif ($whitelisted): ?>
            <span class="chip-badge whitelisted">Whitelisted</span>
          <?php else: ?>
            <span class="chip-badge ghost">Standard</span>
          <?php endif; ?>
        </div>
        <a class="btn ghost" href="<?= $basePath ?>/logout.php">Log ud</a>
      <?php else: ?>
        <a class="btn primary" href="<?= $basePath ?>/login.php">Log ind med Discord</a>
      <?php endif; ?>
    </div>
  </header>
