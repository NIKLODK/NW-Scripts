CREATE TABLE IF NOT EXISTS `nw_drugs` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `drug_key` VARCHAR(64) NOT NULL,
    `label` VARCHAR(128) NOT NULL,
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    `has_harvest` TINYINT(1) NOT NULL DEFAULT 0,
    `has_process` TINYINT(1) NOT NULL DEFAULT 0,
    `harvest_data` LONGTEXT NULL,
    `process_data` LONGTEXT NULL,
    `created_by` VARCHAR(128) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_nw_drugs_drug_key` (`drug_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `nw_drugs_player_stats` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `drug_key` VARCHAR(64) NOT NULL,
    `player_identifier` VARCHAR(128) NOT NULL,
    `player_name` VARCHAR(128) NOT NULL,
    `steam_id` VARCHAR(64) NULL,
    `discord_id` VARCHAR(64) NULL,
    `license_id` VARCHAR(64) NULL,
    `license2_id` VARCHAR(64) NULL,
    `fivem_id` VARCHAR(64) NULL,
    `harvest_count` INT NOT NULL DEFAULT 0,
    `process_count` INT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_nw_drugs_player_unique` (`drug_key`, `player_identifier`),
    KEY `idx_nw_drugs_player_stats_drug_key` (`drug_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
