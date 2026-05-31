ALTER TABLE applications
  ADD COLUMN form_id INT UNSIGNED DEFAULT NULL AFTER discord_user_id,
  ADD COLUMN answered_at DATETIME DEFAULT NULL AFTER updated_at,
  ADD COLUMN notified TINYINT(1) NOT NULL DEFAULT 0 AFTER updated_at;

ALTER TABLE applications
  ADD COLUMN IF NOT EXISTS answered_at DATETIME DEFAULT NULL AFTER updated_at;

CREATE TABLE IF NOT EXISTS application_history (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  application_id INT UNSIGNED NOT NULL,
  form_id INT UNSIGNED DEFAULT NULL,
  type VARCHAR(64) NOT NULL,
  form_title VARCHAR(120) DEFAULT NULL,
  applicant_name VARCHAR(255) NOT NULL,
  discord_user_id VARCHAR(64) DEFAULT NULL,
  content MEDIUMTEXT NOT NULL,
  staff_response TEXT DEFAULT NULL,
  final_status VARCHAR(16) NOT NULL,
  created_at DATETIME NOT NULL,
  answered_at DATETIME DEFAULT NULL,
  archived_at DATETIME NOT NULL,
  delete_reason VARCHAR(32) NOT NULL DEFAULT 'auto_cleanup',
  deleted_by_discord_id VARCHAR(64) DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uniq_application_history_app (application_id),
  KEY idx_app_history_discord (discord_user_id),
  KEY idx_app_history_status (final_status),
  KEY idx_app_history_archived (archived_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS application_forms (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  type VARCHAR(64) NOT NULL,
  title VARCHAR(120) NOT NULL,
  description TEXT NOT NULL,
  questions TEXT NOT NULL,
  webhook_url VARCHAR(2048) DEFAULT NULL,
  visibility VARCHAR(16) NOT NULL DEFAULT 'public',
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE application_forms
  ADD COLUMN IF NOT EXISTS webhook_url VARCHAR(2048) DEFAULT NULL AFTER questions;

ALTER TABLE donations
  ADD COLUMN discord_user_id VARCHAR(64) DEFAULT NULL AFTER stripe_subscription_id;

CREATE TABLE IF NOT EXISTS leaderboard_optin (
  discord_user_id VARCHAR(64) NOT NULL,
  nickname VARCHAR(120) DEFAULT NULL,
  opted_in TINYINT(1) NOT NULL DEFAULT 0,
  updated_at DATETIME NOT NULL,
  PRIMARY KEY (discord_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS stripe_customers (
  stripe_customer_id VARCHAR(255) NOT NULL,
  discord_user_id VARCHAR(64) DEFAULT NULL,
  updated_at DATETIME NOT NULL,
  PRIMARY KEY (stripe_customer_id),
  KEY idx_stripe_customers_discord_user (discord_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS staff_members (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  discord_user_id VARCHAR(64) NOT NULL,
  username VARCHAR(120) DEFAULT NULL,
  display_name VARCHAR(120) DEFAULT NULL,
  avatar_url VARCHAR(255) DEFAULT NULL,
  title VARCHAR(255) DEFAULT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  updated_at DATETIME NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uniq_staff_discord (discord_user_id),
  KEY idx_staff_active (is_active),
  KEY idx_staff_sort (sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS staff_meta (
  id TINYINT(1) NOT NULL,
  last_synced_at DATETIME DEFAULT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO staff_meta (id, last_synced_at)
VALUES (1, NULL)
ON DUPLICATE KEY UPDATE id = id;

CREATE TABLE IF NOT EXISTS rule_categories (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(120) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  updated_at DATETIME NOT NULL,
  PRIMARY KEY (id),
  KEY idx_rule_categories_sort (sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS law_categories (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(120) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  updated_at DATETIME NOT NULL,
  PRIMARY KEY (id),
  KEY idx_law_categories_sort (sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS rules (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  category_id INT UNSIGNED DEFAULT NULL,
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  updated_at DATETIME NOT NULL,
  PRIMARY KEY (id),
  KEY idx_rules_category (category_id),
  KEY idx_rules_sort (sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE rules
  ADD COLUMN IF NOT EXISTS category_id INT UNSIGNED DEFAULT NULL AFTER id,
  ADD COLUMN IF NOT EXISTS sort_order INT NOT NULL DEFAULT 0 AFTER body,
  ADD COLUMN IF NOT EXISTS updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER sort_order;

CREATE TABLE IF NOT EXISTS laws (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  category_id INT UNSIGNED DEFAULT NULL,
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  updated_at DATETIME NOT NULL,
  PRIMARY KEY (id),
  KEY idx_laws_category (category_id),
  KEY idx_laws_sort (sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
