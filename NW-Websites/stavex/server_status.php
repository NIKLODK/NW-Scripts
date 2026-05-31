<?php
require_once __DIR__ . "/includes/config.php";

header("Content-Type: application/json; charset=utf-8");
header("Cache-Control: no-store, no-cache, must-revalidate, max-age=0");
header("Pragma: no-cache");

function fetch_json(string $url, int $timeoutSeconds = 3, ?array &$meta = null, bool $fastOnly = false): ?array
{
    $response = null;
    $status = 0;
    $method = null;
    $error = null;
    $start = microtime(true);
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
        $error = curl_error($ch) ?: null;
        curl_close($ch);
        $method = "curl";
        if ($response !== false && $response !== null && $status >= 200 && $status < 300) {
            $decoded = json_decode($response, true);
            if (is_array($decoded)) {
                if (is_array($meta)) {
                    $meta["method"] = $method;
                    $meta["status"] = $status;
                    $meta["error"] = $error;
                    $meta["duration_ms"] = (int) ((microtime(true) - $start) * 1000);
                }
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
                if (is_array($meta)) {
                    $meta["method"] = "fopen";
                    $meta["status"] = $status;
                    $meta["error"] = null;
                    $meta["duration_ms"] = (int) ((microtime(true) - $start) * 1000);
                }
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
            $method = "curl-cli";
            $response = implode("\n", $output);
            $decoded = json_decode($response, true);
            if (is_array($decoded)) {
                if (is_array($meta)) {
                    $meta["method"] = $method;
                    $meta["status"] = 200;
                    $meta["error"] = null;
                    $meta["duration_ms"] = (int) ((microtime(true) - $start) * 1000);
                }
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
        $method = "fopen";
        $error = null;
        if ($response === false) {
            $lastError = error_get_last();
            $error = is_array($lastError) ? ($lastError["message"] ?? null) : null;
        }
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
                if (is_array($meta)) {
                    $meta["method"] = $method;
                    $meta["status"] = $status;
                    $meta["error"] = $error;
                    $meta["duration_ms"] = (int) ((microtime(true) - $start) * 1000);
                }
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
        if (is_array($meta)) {
            $meta["method"] = "socket";
            $meta["status"] = $status;
            $meta["error"] = $errstr ?: $error;
            $meta["duration_ms"] = (int) ((microtime(true) - $start) * 1000);
        }
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
        if (is_array($meta)) {
            $meta["method"] = "socket";
            $meta["status"] = $status;
            $meta["error"] = $error;
            $meta["duration_ms"] = (int) ((microtime(true) - $start) * 1000);
        }
        return null;
    }

    $parts = explode("\r\n\r\n", $raw, 2);
    $headers = $parts[0] ?? "";
    $body = $parts[1] ?? "";
    if (preg_match("/^HTTP\\/\\d+\\.\\d+\\s+(\\d+)/", $headers, $matches)) {
        $status = (int) $matches[1];
    }

    if ($status < 200 || $status >= 300) {
        if (is_array($meta)) {
            $meta["method"] = "socket";
            $meta["status"] = $status;
            $meta["error"] = $error;
            $meta["duration_ms"] = (int) ((microtime(true) - $start) * 1000);
        }
        return null;
    }

    $decoded = json_decode($body, true);
    if (is_array($meta)) {
        $meta["method"] = "socket";
        $meta["status"] = $status;
        $meta["error"] = $error;
        $meta["duration_ms"] = (int) ((microtime(true) - $start) * 1000);
    }
    return is_array($decoded) ? $decoded : null;
}

$endpoint = defined("FIVEM_SERVER_ENDPOINT") ? trim(FIVEM_SERVER_ENDPOINT) : "";
$cfxCode = defined("FIVEM_SERVER_CFX_CODE") ? trim(FIVEM_SERVER_CFX_CODE) : "";
$joinUrl = defined("FIVEM_SERVER_JOIN_URL") ? trim(FIVEM_SERVER_JOIN_URL) : "";
$endpointConfigured = $endpoint !== "";
$debug = isset($_GET["debug"]) && $_GET["debug"] === "1";
$debugInfo = [];

if ($joinUrl === "" && $cfxCode !== "") {
    $joinUrl = "https://cfx.re/join/" . $cfxCode;
}

if ($endpointConfigured) {
    $endpoint = rtrim($endpoint, "/");
    $infoMeta = $debug ? [] : null;
    $info = fetch_json($endpoint . "/info.json", 1, $infoMeta, true);
    if ($debug && is_array($infoMeta)) {
        $debugInfo["endpoint_info"] = $infoMeta;
    }
    if ($info) {
        $playersMeta = $debug ? [] : null;
        $players = fetch_json($endpoint . "/players.json", 1, $playersMeta, true);
        if ($debug && is_array($playersMeta)) {
            $debugInfo["endpoint_players"] = $playersMeta;
        }
        $playerCount = is_array($players) ? count($players) : null;

        $maxPlayers = null;
        if (isset($info["vars"]["sv_maxclients"])) {
            $maxPlayers = (int) $info["vars"]["sv_maxclients"];
        } elseif (isset($info["vars"]["sv_maxClients"])) {
            $maxPlayers = (int) $info["vars"]["sv_maxClients"];
        }

        $hostname = $info["vars"]["sv_hostname"] ?? null;
        $connect = defined("FIVEM_SERVER_CONNECT") && FIVEM_SERVER_CONNECT !== "" ? FIVEM_SERVER_CONNECT : null;

        $payload = [
            "configured" => true,
            "online" => true,
            "players" => $playerCount,
            "maxPlayers" => $maxPlayers,
            "hostname" => $hostname,
            "connect" => $connect,
            "joinUrl" => $joinUrl !== "" ? $joinUrl : null,
        ];
        if ($debug) {
            $payload["debug"] = $debugInfo;
        }
        echo json_encode($payload);
        exit;
    }
}

if ($cfxCode !== "") {
    $cfxMeta = $debug ? [] : null;
    $cfxData = fetch_json("https://servers-frontend.fivem.net/api/servers/single/" . rawurlencode($cfxCode), 3, $cfxMeta);
    if ($debug && is_array($cfxMeta)) {
        $debugInfo["cfx"] = $cfxMeta;
    }
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

        $connect = defined("FIVEM_SERVER_CONNECT") && FIVEM_SERVER_CONNECT !== ""
            ? FIVEM_SERVER_CONNECT
            : (!empty($data["connectEndPoints"][0]) ? "connect " . $data["connectEndPoints"][0] : null);

        $payload = [
            "configured" => true,
            "online" => true,
            "players" => $playerCount,
            "maxPlayers" => $maxPlayers,
            "hostname" => $hostname,
            "connect" => $connect,
            "joinUrl" => $joinUrl !== "" ? $joinUrl : null,
        ];
        if ($debug) {
            $payload["debug"] = $debugInfo;
        }
        echo json_encode($payload);
        exit;
    }
}

$payload = [
    "configured" => ($endpointConfigured || $cfxCode !== ""),
    "online" => false,
    "joinUrl" => $joinUrl !== "" ? $joinUrl : null,
];
if ($debug) {
    $payload["debug"] = $debugInfo;
}
echo json_encode($payload);
