<?php
require_once __DIR__ . "/config.php";

function db(): mysqli
{
    static $conn;
    if ($conn instanceof mysqli) {
        return $conn;
    }

    $conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
    if ($conn->connect_error) {
        http_response_code(500);
        echo "Database forbindelse fejlede: " . htmlspecialchars($conn->connect_error);
        exit;
    }

    $conn->set_charset("utf8mb4");
    return $conn;
}

function db_fetch_all(string $sql, array $params = []): array
{
    $conn = db();
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        return [];
    }

    if (!empty($params)) {
        $types = str_repeat("s", count($params));
        $stmt->bind_param($types, ...$params);
    }

    $stmt->execute();
    $result = $stmt->get_result();
    $rows = $result ? $result->fetch_all(MYSQLI_ASSOC) : [];
    $stmt->close();

    return $rows;
}

function db_execute(string $sql, array $params = []): bool
{
    $conn = db();
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        return false;
    }

    if (!empty($params)) {
        $types = str_repeat("s", count($params));
        $stmt->bind_param($types, ...$params);
    }

    $ok = $stmt->execute();
    $stmt->close();

    return $ok;
}
