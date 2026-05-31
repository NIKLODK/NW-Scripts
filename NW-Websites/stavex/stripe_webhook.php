<?php
require_once __DIR__ . "/includes/config.php";
require_once __DIR__ . "/includes/db.php";

if (STRIPE_WEBHOOK_SECRET === "YOUR_STRIPE_WEBHOOK_SECRET") {
    http_response_code(500);
    echo "Stripe webhook secret mangler i includes/config.php";
    exit;
}

$payload = file_get_contents("php://input");
$sigHeader = $_SERVER["HTTP_STRIPE_SIGNATURE"] ?? "";

function webhook_log(string $message): void
{
    $path = __DIR__ . "/stripe_webhook.log";
    $line = "[" . date("Y-m-d H:i:s") . "] " . $message . PHP_EOL;
    @file_put_contents($path, $line, FILE_APPEND);
}

function verify_stripe_signature(string $payload, string $sigHeader, string $secret): bool
{
    if ($sigHeader === "") {
        webhook_log("Missing Stripe-Signature header");
        return false;
    }

    $parts = explode(",", $sigHeader);
    $timestamp = null;
    $signatures = [];

    foreach ($parts as $part) {
        [$key, $value] = array_pad(explode("=", trim($part), 2), 2, null);
        if ($key === "t") {
            $timestamp = $value;
        }
        if ($key === "v1") {
            $signatures[] = $value;
        }
    }

    if ($timestamp === null || empty($signatures)) {
        webhook_log("Invalid signature header format");
        return false;
    }

    // Optional tolerance check (15 min)
    if (abs(time() - (int) $timestamp) > 900) {
        webhook_log("Signature timestamp outside tolerance");
        return false;
    }

    $signedPayload = $timestamp . "." . $payload;
    $expected = hash_hmac("sha256", $signedPayload, $secret);

    foreach ($signatures as $signature) {
        if (hash_equals($expected, $signature)) {
            return true;
        }
    }

    webhook_log("Signature verification failed");
    return false;
}

if (!verify_stripe_signature($payload, $sigHeader, STRIPE_WEBHOOK_SECRET)) {
    http_response_code(400);
    echo "Invalid signature";
    exit;
}

$event = json_decode($payload, true);
if (!is_array($event)) {
    http_response_code(400);
    echo "Invalid payload";
    exit;
}

$eventType = $event["type"] ?? "";
$eventId = $event["id"] ?? "";
$object = $event["data"]["object"] ?? [];

webhook_log("Received event: " . $eventType . " (" . $eventId . ")");

function insert_donation(array $data): void
{
    $sql = "INSERT INTO donations (stripe_event_id, stripe_payment_intent_id, stripe_subscription_id, discord_user_id, discord_name, amount, currency, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)";

    db_execute($sql, [
        $data["event_id"],
        $data["payment_intent"],
        $data["subscription_id"],
        $data["discord_user_id"],
        $data["discord_name"],
        $data["amount"],
        $data["currency"],
        $data["created_at"],
    ]);
}

function upsert_customer_map(?string $customerId, ?string $discordUserId): void
{
    if (!$customerId || !$discordUserId) {
        return;
    }

    $sql = "INSERT INTO stripe_customers (stripe_customer_id, discord_user_id, updated_at)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE discord_user_id = VALUES(discord_user_id), updated_at = VALUES(updated_at)";
    db_execute($sql, [
        $customerId,
        $discordUserId,
        date("Y-m-d H:i:s"),
    ]);
}

function get_discord_id_from_customer(?string $customerId): ?string
{
    if (!$customerId) {
        return null;
    }
    $rows = db_fetch_all(
        "SELECT discord_user_id FROM stripe_customers WHERE stripe_customer_id = ? LIMIT 1",
        [$customerId]
    );
    return $rows[0]["discord_user_id"] ?? null;
}

if ($eventType === "checkout.session.completed") {
    $paymentIntent = $object["payment_intent"] ?? "";
    $amountTotal = $object["amount_total"] ?? 0;
    $currency = $object["currency"] ?? STRIPE_CURRENCY;
    $created = $object["created"] ?? time();
    $subscriptionId = $object["subscription"] ?? null;
    $discordName = $object["metadata"]["discord_name"] ?? null;
    $discordUserId = $object["metadata"]["discord_user_id"] ?? null;
    $clientRef = $object["client_reference_id"] ?? null;
    if ($discordUserId === null && $clientRef) {
        $discordUserId = $clientRef;
    }
    $customerId = $object["customer"] ?? null;

    if ($paymentIntent !== "" && $amountTotal > 0) {
        insert_donation([
            "event_id" => $eventId,
            "payment_intent" => $paymentIntent,
            "subscription_id" => $subscriptionId,
            "discord_user_id" => $discordUserId,
            "discord_name" => $discordName,
            "amount" => (int) $amountTotal,
            "currency" => $currency,
            "created_at" => date("Y-m-d H:i:s", (int) $created),
        ]);
    }

    upsert_customer_map($customerId, $discordUserId);
}

if ($eventType === "invoice.paid" || $eventType === "invoice.payment_succeeded") {
    $paymentIntent = $object["payment_intent"] ?? "";
    $amountPaid = $object["amount_paid"] ?? 0;
    $currency = $object["currency"] ?? STRIPE_CURRENCY;
    $created = $object["created"] ?? time();
    $subscriptionId = $object["subscription"] ?? null;
    $discordName = $object["customer_name"] ?? null;
    $discordUserId = $object["metadata"]["discord_user_id"] ?? null;
    $customerId = $object["customer"] ?? null;
    if ($discordUserId === null && $customerId) {
        $discordUserId = get_discord_id_from_customer($customerId);
    }

    if ($paymentIntent !== "" && $amountPaid > 0) {
        insert_donation([
            "event_id" => $eventId,
            "payment_intent" => $paymentIntent,
            "subscription_id" => $subscriptionId,
            "discord_user_id" => $discordUserId,
            "discord_name" => $discordName,
            "amount" => (int) $amountPaid,
            "currency" => $currency,
            "created_at" => date("Y-m-d H:i:s", (int) $created),
        ]);
    }

    upsert_customer_map($customerId, $discordUserId);
}

http_response_code(200);
echo "ok";
