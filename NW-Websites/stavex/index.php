<?php
require_once __DIR__ . "/includes/header.php";
require_once __DIR__ . "/includes/staff.php";

function fetch_status_json(string $url, int $timeoutSeconds = 3, bool $fastOnly = false): ?array
{
  $response = null;
  $status = 0;
  $userAgent = "StavexRP-Status/1.0";

  $usedCurl = false;
  if (function_exists("curl_init")) {
    $usedCurl = true;
    $ch = curl_init($url);
    if ($ch === false) {
      return null;
    }

    curl_setopt_array($ch, [
      CURLOPT_RETURNTRANSFER => true,
      CURLOPT_CONNECTTIMEOUT => $timeoutSeconds,
      CURLOPT_TIMEOUT => $timeoutSeconds,
      CURLOPT_FOLLOWLOCATION => true,
      CURLOPT_HTTPHEADER => ["Accept: application/json"],
      CURLOPT_USERAGENT => $userAgent,
      CURLOPT_SSL_VERIFYPEER => false,
      CURLOPT_SSL_VERIFYHOST => 0,
    ]);

    $response = curl_exec($ch);
    $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    if ($response !== false && $response !== null && $status >= 200 && $status < 300) {
      $decoded = json_decode($response, true);
      if (is_array($decoded)) {
        return $decoded;
      }
    }
    if ($fastOnly) {
      return null;
    }
  }

  if ($fastOnly && !$usedCurl && function_exists("file_get_contents")) {
    $context = stream_context_create([
      "http" => [
        "timeout" => $timeoutSeconds,
        "header" => "Accept: application/json\r\nUser-Agent: " . $userAgent . "\r\n",
      ],
      "ssl" => [
        "verify_peer" => false,
        "verify_peer_name" => false,
      ],
    ]);
    $response = @file_get_contents($url, false, $context);
    if (isset($http_response_header) && is_array($http_response_header)) {
      foreach ($http_response_header as $header) {
        if (preg_match("/^HTTP\\/\\d+\\.\\d+\\s+(\\d+)/", $header, $matches)) {
          $status = (int) $matches[1];
          break;
        }
      }
    }
    if ($response !== false && $response !== null && $status >= 200 && $status < 300) {
      $decoded = json_decode($response, true);
      if (is_array($decoded)) {
        return $decoded;
      }
    }
    return null;
  }

  if (function_exists("exec")) {
    $output = [];
    $code = 1;
    $cmd = "curl -sL --max-time " . (int) $timeoutSeconds . " --connect-timeout " . (int) $timeoutSeconds . " -H \"Accept: application/json\" -A \"" . $userAgent . "\" -k " . escapeshellarg($url);
    @exec($cmd, $output, $code);
    if ($code === 0 && !empty($output)) {
      $response = implode("\n", $output);
      $decoded = json_decode($response, true);
      if (is_array($decoded)) {
        return $decoded;
      }
    }
  }

  if (function_exists("file_get_contents")) {
    $context = stream_context_create([
      "http" => [
        "timeout" => $timeoutSeconds,
        "header" => "Accept: application/json\r\nUser-Agent: " . $userAgent . "\r\n",
      ],
      "ssl" => [
        "verify_peer" => false,
        "verify_peer_name" => false,
      ],
    ]);
    $response = @file_get_contents($url, false, $context);
    if (isset($http_response_header) && is_array($http_response_header)) {
      foreach ($http_response_header as $header) {
        if (preg_match("/^HTTP\\/\\d+\\.\\d+\\s+(\\d+)/", $header, $matches)) {
          $status = (int) $matches[1];
          break;
        }
      }
    }
    if ($response !== false && $response !== null && $status >= 200 && $status < 300) {
      $decoded = json_decode($response, true);
      if (is_array($decoded)) {
        return $decoded;
      }
    }
  }

  $parts = parse_url($url);
  if (!is_array($parts) || empty($parts["host"])) {
    return null;
  }

  $scheme = $parts["scheme"] ?? "http";
  $host = $parts["host"];
  $port = $parts["port"] ?? ($scheme === "https" ? 443 : 80);
  $path = $parts["path"] ?? "/";
  if (!empty($parts["query"])) {
    $path .= "?" . $parts["query"];
  }

  $target = ($scheme === "https" ? "ssl://" : "") . $host;
  $fp = @fsockopen($target, $port, $errno, $errstr, $timeoutSeconds);
  if (!$fp) {
    return null;
  }

  stream_set_timeout($fp, $timeoutSeconds);
  $request = "GET " . $path . " HTTP/1.1\r\n";
  $request .= "Host: " . $host . "\r\n";
  $request .= "Accept: application/json\r\n";
  $request .= "User-Agent: " . $userAgent . "\r\n";
  $request .= "Connection: close\r\n\r\n";
  fwrite($fp, $request);
  $raw = stream_get_contents($fp);
  fclose($fp);

  if ($raw === false || $raw === null) {
    return null;
  }

  $parts = explode("\r\n\r\n", $raw, 2);
  $headers = $parts[0] ?? "";
  $body = $parts[1] ?? "";
  if (preg_match("/^HTTP\\/\\d+\\.\\d+\\s+(\\d+)/", $headers, $matches)) {
    $status = (int) $matches[1];
  }

  if ($status < 200 || $status >= 300) {
    return null;
  }

  $decoded = json_decode($body, true);
  return is_array($decoded) ? $decoded : null;
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

$statusLabelText = "Henter status...";
$statusPlayersText = "-";
$statusClass = "";
$endpoint = defined("FIVEM_SERVER_ENDPOINT") ? trim(FIVEM_SERVER_ENDPOINT) : "";
$cfxCode = defined("FIVEM_SERVER_CFX_CODE") ? trim(FIVEM_SERVER_CFX_CODE) : "";
$joinUrl = defined("FIVEM_SERVER_JOIN_URL") ? trim(FIVEM_SERVER_JOIN_URL) : "";
$initialStatus = null;
$endpointConfigured = $endpoint !== "";

if ($joinUrl === "" && $cfxCode !== "") {
  $joinUrl = "https://cfx.re/join/" . $cfxCode;
}

if ($endpointConfigured) {
  $endpoint = rtrim($endpoint, "/");
  $info = fetch_status_json($endpoint . "/info.json", 1, true);
  if ($info) {
    $players = fetch_status_json($endpoint . "/players.json", 1, true);
    $playerCount = is_array($players) ? count($players) : null;

    $maxPlayers = null;
    if (isset($info["vars"]["sv_maxclients"])) {
      $maxPlayers = (int) $info["vars"]["sv_maxclients"];
    } elseif (isset($info["vars"]["sv_maxClients"])) {
      $maxPlayers = (int) $info["vars"]["sv_maxClients"];
    }

    $hostname = $info["vars"]["sv_hostname"] ?? null;

    $initialStatus = [
      "configured" => true,
      "online" => true,
      "players" => $playerCount,
      "maxPlayers" => $maxPlayers,
      "hostname" => $hostname,
    ];
  }
}

if (!$initialStatus && $cfxCode !== "") {
  $cfxData = fetch_status_json("https://servers-frontend.fivem.net/api/servers/single/" . rawurlencode($cfxCode), 2);
  if (is_array($cfxData) && isset($cfxData["Data"]) && is_array($cfxData["Data"])) {
    $data = $cfxData["Data"];
    $clients = isset($data["clients"]) ? (int) $data["clients"] : null;
    $selfReported = isset($data["selfReportedClients"]) ? (int) $data["selfReportedClients"] : null;
    if ($clients === null) {
      $playerCount = $selfReported;
    } elseif ($selfReported === null) {
      $playerCount = $clients;
    } else {
      $playerCount = max($clients, $selfReported);
    }
    $maxPlayers = null;
    if (isset($data["sv_maxclients"])) {
      $maxPlayers = (int) $data["sv_maxclients"];
    } elseif (isset($data["svMaxclients"])) {
      $maxPlayers = (int) $data["svMaxclients"];
    } elseif (isset($data["vars"]["sv_maxClients"])) {
      $maxPlayers = (int) $data["vars"]["sv_maxClients"];
    }

    $hostname = $data["hostname"] ?? ($data["vars"]["sv_projectName"] ?? null);

    $initialStatus = [
      "configured" => true,
      "online" => true,
      "players" => $playerCount,
      "maxPlayers" => $maxPlayers,
      "hostname" => $hostname,
    ];
  }
}

if (is_array($initialStatus)) {
  if (empty($initialStatus["configured"])) {
    $statusLabelText = "Server status ikke sat op endnu";
    $statusClass = "is-offline";
  } elseif (!empty($initialStatus["online"])) {
    $statusLabelText = "Online";
    $statusClass = "is-online";
    if (array_key_exists("players", $initialStatus) && is_numeric($initialStatus["players"])) {
      $statusPlayersText = (int) $initialStatus["players"] . " spillere online";
      if (array_key_exists("maxPlayers", $initialStatus) && is_numeric($initialStatus["maxPlayers"])) {
        $statusPlayersText .= " / " . (int) $initialStatus["maxPlayers"] . " slots";
      }
    }
  } else {
    $statusLabelText = "Offline";
    $statusPlayersText = "0 spillere online";
    $statusClass = "is-offline";
  }
} else {
  $statusLabelText = "Offline";
  $statusPlayersText = "0 spillere online";
  $statusClass = "is-offline";
}

staff_maybe_sync();
$staffMembers = db_fetch_all(
  "SELECT discord_user_id, username, display_name, avatar_url, title
   FROM staff_members
   WHERE is_active = 1
   ORDER BY sort_order DESC, display_name ASC"
);
?>
<script>
  document.body.classList.add("home-rotating-bg");
</script>
<div class="home-bg-rotator" aria-hidden="true">
  <span class="home-bg-slide slide-1"></span>
  <span class="home-bg-slide slide-2"></span>
  <span class="home-bg-slide slide-3"></span>
</div>
<div class="home-bg-overlay" aria-hidden="true"></div>

  <main>
    <section id="hjem" class="hero">
      <div class="hero-content">
        <p class="eyebrow">StavexRP</p>
        <h1>Stedet for dig, der søger seriøs RP, samt et fælles community. Ønsker du at bidrage? Så læg en ansøgning og bliv medlem af fællesskabet i dag</h1>
        <p>
          StavexRP blev startet for at skabe en stabil server med fokus på kvalitet og tryghed.
          Vi vil give alle spillere en tydelig ramme for RP – med plads til kreativitet, udvikling og respekt.
        </p>
        <div class="hero-actions">
          <a class="btn primary" href="<?= $basePath ?>/applications.php">Se ansøgninger</a>
          <a class="btn ghost" href="<?= $basePath ?>/donate.php">❤️ Støt serveren</a>
        </div>
      </div>
      <div class="hero-media">
        <div class="tri-slice">
          <div class="slice slice-1" role="img" aria-label="StavexRP scene 1"></div>
          <div class="slice slice-2" role="img" aria-label="StavexRP scene 2"></div>
          <div class="slice slice-3" role="img" aria-label="StavexRP scene 3"></div>
        </div>
        <div class="media-grid">
          <img src="<?= $basePath ?>/images/gallery-1.png" alt="StavexRP scene" />
          <img src="<?= $basePath ?>/images/gallery-2.webp" alt="StavexRP scene" />
          <img src="<?= $basePath ?>/images/gallery-3.png" alt="StavexRP scene" />
          <img src="<?= $basePath ?>/images/gallery-4.png" alt="StavexRP scene" />
        </div>
      </div>
    </section>

    <!-- <section class="story">
      <div>
        <h2>Projektets historie</h2>
        <p>
          StavexRP blev grundlagt af <strong>NIKLO</strong>, <strong>Good Times</strong> og <strong>DiegoA</strong> for at løse den
          klassiske udfordring: stabil RP med tydelige regler og et engageret staff-team.
        </p>
        <p>
          Vi fokuserer på transparent kommunikation, fair behandling og en løbende dialog med community.
          Derfor har vi også åbne ansøgningsprocesser og klare donation goals.
        </p>
      </div>
      <div class="callout">
        <h3>Mission</h3>
        <p>Skabe den mest stabile og trygge danske RP-server med plads til kvalitetshistorier.</p>
        <h3>Vision</h3>
        <p>Et community hvor spillerne er stolte af at bidrage, og hvor staff er synlige og retfærdige.</p>
      </div>
    </section> -->

    <section id="server-status" class="server-status">
      <div class="section-heading">
        <h2>Server status</h2>
        <p>Live status for StavexRP FiveM serveren.</p>
      </div>
      <div class="status-card <?= htmlspecialchars($statusClass) ?>" id="serverStatus" data-endpoint="<?= $basePath ?>/server_status.php">
        <div class="status-line">
          <span class="status-dot" aria-hidden="true"></span>
          <strong class="status-label"><?= htmlspecialchars($statusLabelText) ?></strong>
        </div>
        <div class="status-meta">
          <span class="status-players" id="serverPlayers"><?= htmlspecialchars($statusPlayersText) ?></span>
        </div>
        <?php if ($joinUrl !== ""): ?>
          <div class="status-actions">
            <a class="btn primary full" id="serverJoinBtn" href="<?= htmlspecialchars($joinUrl) ?>">Tilslut</a>
          </div>
        <?php endif; ?>
        <?php if (defined("FIVEM_SERVER_CONNECT") && FIVEM_SERVER_CONNECT !== ""): ?>
          <div class="status-connect">
            F8 KODE: <code><?= htmlspecialchars(FIVEM_SERVER_CONNECT) ?></code>
          </div>
        <?php endif; ?>
      </div>
    </section>

        <section id="staff" class="staff">
      <div class="section-heading">
        <h2>Staff Team</h2>
        <p>Mød stifterne og kerneholdet bag StavexRP.</p>
      </div>
      <div class="staff-marquee">
        <div class="staff-track">
          <?php if (!empty($staffMembers)): ?>
            <?php foreach ($staffMembers as $member): ?>
              <?php
                $name = $member["display_name"] ?? ($member["username"] ?? "Staff");
                $titleLine = $member["title"] ?? "";
                $avatarUrl = $member["avatar_url"] ?? "";
              ?>
              <article class="staff-card">
                <div class="avatar">
                  <?php if ($avatarUrl): ?>
                    <img src="<?= htmlspecialchars($avatarUrl) ?>" alt="Discord avatar for <?= htmlspecialchars($name) ?>" />
                  <?php else: ?>
                    <?= htmlspecialchars(staff_initials($name)) ?>
                  <?php endif; ?>
                </div>
                <h3><?= htmlspecialchars($name) ?></h3>
                <?php if ($titleLine !== ""): ?>
                  <p class="staff-title"><span><?= htmlspecialchars($titleLine) ?></span></p>
                <?php else: ?>
                  <p class="staff-title muted"><span>Staff</span></p>
                <?php endif; ?>
              </article>
            <?php endforeach; ?>
            <?php foreach ($staffMembers as $member): ?>
              <?php
                $name = $member["display_name"] ?? ($member["username"] ?? "Staff");
                $titleLine = $member["title"] ?? "";
                $avatarUrl = $member["avatar_url"] ?? "";
              ?>
              <article class="staff-card">
                <div class="avatar">
                  <?php if ($avatarUrl): ?>
                    <img src="<?= htmlspecialchars($avatarUrl) ?>" alt="Discord avatar for <?= htmlspecialchars($name) ?>" />
                  <?php else: ?>
                    <?= htmlspecialchars(staff_initials($name)) ?>
                  <?php endif; ?>
                </div>
                <h3><?= htmlspecialchars($name) ?></h3>
                <?php if ($titleLine !== ""): ?>
                  <p class="staff-title"><span><?= htmlspecialchars($titleLine) ?></span></p>
                <?php else: ?>
                  <p class="staff-title muted"><span>Staff</span></p>
                <?php endif; ?>
              </article>
            <?php endforeach; ?>
          <?php else: ?>
            <article class="staff-card">
              <div class="avatar">NK</div>
              <h3>NIKLO</h3>
              <p class="staff-title"><span>Stifter • Head Udvikler • Staff Management</span></p>
            </article>
            <article class="staff-card">
              <div class="avatar">GT</div>
              <h3>Good Times</h3>
              <p class="staff-title"><span>Stifter • Manager</span></p>
            </article>
            <article class="staff-card">
              <div class="avatar">DA</div>
              <h3>DiegoA</h3>
              <p class="staff-title"><span>Stifter • Manager</span></p>
            </article>
            <article class="staff-card">
              <div class="avatar">SD</div>
              <h3>SquizeeDK</h3>
              <p class="staff-title"><span>Udvikler</span></p>
            </article>
            <article class="staff-card">
              <div class="avatar">NK</div>
              <h3>NIKLO</h3>
              <p class="staff-title"><span>Stifter • Head Udvikler • Staff Management</span></p>
            </article>
            <article class="staff-card">
              <div class="avatar">GT</div>
              <h3>Good Times</h3>
              <p class="staff-title"><span>Stifter • Manager</span></p>
            </article>
            <article class="staff-card">
              <div class="avatar">DA</div>
              <h3>DiegoA</h3>
              <p class="staff-title"><span>Stifter • Manager</span></p>
            </article>
            <article class="staff-card">
              <div class="avatar">SD</div>
              <h3>SquizeeDK</h3>
              <p class="staff-title"><span>Udvikler</span></p>
            </article>
          <?php endif; ?>
        </div>
      </div>
    </section>

  </main>

<?php
require_once __DIR__ . "/includes/footer.php";
?>
