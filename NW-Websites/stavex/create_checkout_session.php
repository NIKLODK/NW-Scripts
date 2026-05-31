<?php
require_once __DIR__ . "/includes/config.php";
require_once __DIR__ . "/includes/auth.php";

if (!is_logged_in()) {
    header("Location: login.php");
    exit;
}

if (STRIPE_SECRET_KEY === "YOUR_STRIPE_SECRET_KEY") {
    http_response_code(500);
    echo "Stripe secret key mangler i includes/config.php";
    exit;
}

$successUrl = "http://89.35.30.41:5215/donate.php?status=success";
$cancelUrl  = "http://89.35.30.41:5215/donate.php?status=cancel";

$discordName = $_POST["discord_name"] ?? "";
$discordName = trim($discordName);

$user = discord_user();
$discordUserId = $user["id"] ?? "";
$discordUsername = $user["username"] ?? "";

$payload = [
    "mode" => "subscription",
    "success_url" => $successUrl,
    "cancel_url" => $cancelUrl,
    "subscription_data" => [
        "metadata" => [],
    ],
    "line_items" => [[
        "quantity" => 1,
        "price_data" => [
            "currency" => STRIPE_CURRENCY,
            "unit_amount" => STRIPE_MONTHLY_AMOUNT,
            "recurring" => ["interval" => "month"],
            "product" => STRIPE_PRODUCT_ID,
        ],
    ]],
];

if ($discordName === "" && $discordUsername !== "") {
    $discordName = $discordUsername;
}

if ($discordName !== "") {
    $_SESSION["last_donation_name"] = $discordName;
}

$metadata = [];
if ($discordName !== "") {
    $metadata["discord_name"] = $discordName;
}
if ($discordUserId !== "") {
    $payload["client_reference_id"] = $discordUserId;
    $metadata["discord_user_id"] = $discordUserId;
}
if ($discordUsername !== "") {
    $metadata["discord_username"] = $discordUsername;
}
if (!empty($metadata)) {
    $payload["metadata"] = $metadata;
    $payload["subscription_data"]["metadata"] = $metadata;
}

$ch = curl_init("https://api.stripe.com/v1/checkout/sessions");
curl_setopt_array($ch, [
    CURLOPT_POST => true,
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_POSTFIELDS => http_build_query($payload),
    CURLOPT_HTTPHEADER => [
        "Authorization: Bearer " . STRIPE_SECRET_KEY,
        "Content-Type: application/x-www-form-urlencoded",
    ],
]);

$response = curl_exec($ch);
$status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curlError = curl_error($ch);
curl_close($ch);

if ($response === false || $status < 200 || $status >= 300) {
    http_response_code(500);
    echo "Stripe fejl: " . htmlspecialchars($curlError ?: $response);
    exit;
}

$data = json_decode($response, true);
if (!is_array($data) || empty($data["url"])) {
    http_response_code(500);
    echo "Stripe session kunne ikke oprettes.";
    exit;
}

header("Location: " . $data["url"]);
exit;
