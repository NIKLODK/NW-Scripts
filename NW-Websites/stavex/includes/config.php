<?php
// Discord OAuth config
// TODO: Fill these with your Discord application credentials.
const DISCORD_CLIENT_ID = "";
const DISCORD_CLIENT_SECRET = "";
const DISCORD_REDIRECT_URI = "http://localhost/stavex/callback.php";

// Discord guild + whitelist role (for whitelist access)
const DISCORD_GUILD_ID = "1439862320737026070";
const DISCORD_WHITELIST_ROLE_ID = "1446976487944355902";
const DISCORD_STAFF_ROLE_ID = "1470874573850415184";
const DISCORD_UNTRUSTED_ROLE_ID = "1446976459150196851";
const DISCORD_SUPERUSER_IDS = ["291255160590827520", "1372509510874169354"];
// Bot token required for staff sync (enable Server Members Intent in Discord Developer Portal).
const DISCORD_BOT_TOKEN = "MTQ0Njk4NDI5MDk2NDYwMzAzMA.GwgPDy.WTJz0RbuXZKjgvUSvP7YwapuffbhEgVD3gwNgo";
// Preferred target for new application alerts (Discord channel ID).
const DISCORD_APPLICATION_CHANNEL_ID = "1475133510858576084";
// Secret used to sign Discord approve/deny action links.
const DISCORD_APPLICATION_ACTION_SECRET = "";
// Discord webhook URL used when a new application is created.
// Used as fallback if channel ID is not configured.
const DISCORD_APPLICATION_WEBHOOK_URL = "https://discord.com/api/webhooks/1475133556794724523/T5KheM5oJgxjA_xfctDJN-_eynXh2EBrGSnChs2r1G9hsKhMIASbZMwwwL6WXqO-6ItP";
// Sync interval in minutes for staff roster updates.
const DISCORD_STAFF_SYNC_MINUTES = 10;

const DISCORD_OAUTH_SCOPES = "identify guilds.members.read";

const SITE_NAME = "StavexRP";
const SITE_BASE_URL = "http://localhost/stavex";

// FiveM server status config
// Example endpoint: http://127.0.0.1:30120
// Example connect: connect 127.0.0.1:30120
const FIVEM_SERVER_ENDPOINT = "http://89.35.30.41:30120";
const FIVEM_SERVER_CONNECT = "connect 89.35.30.41:30120";
const FIVEM_SERVER_CFX_CODE = "5d7v9z";
const FIVEM_SERVER_JOIN_URL = "https://cfx.re/join/5d7v9z";

// Stripe config
// TODO: Fill this with your Stripe secret key (starts with sk_live_ or sk_test_).
const STRIPE_SECRET_KEY = "";
const STRIPE_PRODUCT_ID = "prod_TuXLthIAkTP2Jz";
const STRIPE_CURRENCY = "dkk";
const STRIPE_MONTHLY_AMOUNT = 7500; // 75.00 DKK in the smallest currency unit
const STRIPE_WEBHOOK_SECRET = "whsec_nLAy7cCZZz9PvhSSS4rnLVuHB7X64A5X";

// Database config (MySQL)
const DB_HOST = "db.glnodes.com:50000";
const DB_NAME = "s54_stavex";
const DB_USER = "u54_jrbLK9v5zF";
const DB_PASS = "P1ZjIl8W0FFyExh77k1A!a.3";

// Donation goal (in DKK)
const DONATION_GOAL_AMOUNT = 20000;

function discord_auth_url(): string
{
    $params = http_build_query([
        "client_id" => DISCORD_CLIENT_ID,
        "redirect_uri" => DISCORD_REDIRECT_URI,
        "response_type" => "code",
        "scope" => DISCORD_OAUTH_SCOPES,
        "prompt" => "consent",
    ]);

    return "https://discord.com/api/oauth2/authorize?" . $params;
}
