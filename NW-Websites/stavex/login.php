<?php
require_once __DIR__ . "/includes/config.php";
header("Location: " . discord_auth_url());
exit;
