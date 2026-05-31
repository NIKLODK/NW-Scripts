-- NW-Bande rank migration for HeidiSQL
-- Run this on the same database where tables `gangs`, `members`, `users` exist.

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS gang_ranks (
    id INT NOT NULL AUTO_INCREMENT,
    gang_id INT NOT NULL,
    rank_name VARCHAR(24) NOT NULL,
    rank_order INT NOT NULL,
    can_invite TINYINT(1) NOT NULL DEFAULT 0,
    can_start_mission TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uq_gang_rank_name (gang_id, rank_name),
    KEY idx_gang_ranks_gang (gang_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Add columns if missing (works on older MySQL/MariaDB too)
SET @has_col := (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'gang_ranks'
      AND COLUMN_NAME = 'can_invite'
);
SET @sql := IF(@has_col = 0,
    'ALTER TABLE gang_ranks ADD COLUMN can_invite TINYINT(1) NOT NULL DEFAULT 0',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_col := (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'gang_ranks'
      AND COLUMN_NAME = 'can_start_mission'
);
SET @sql := IF(@has_col = 0,
    'ALTER TABLE gang_ranks ADD COLUMN can_start_mission TINYINT(1) NOT NULL DEFAULT 0',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Drop old unique index on rank_order if it exists (caused duplicate-key errors while reordering)
SET @has_idx := (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'gang_ranks'
      AND INDEX_NAME = 'uq_gang_rank_order'
);
SET @sql := IF(@has_idx > 0,
    'ALTER TABLE gang_ranks DROP INDEX uq_gang_rank_order',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Optional non-unique index for fast rank sorting
SET @has_idx := (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'gang_ranks'
      AND INDEX_NAME = 'idx_gang_rank_order'
);
SET @sql := IF(@has_idx = 0,
    'CREATE INDEX idx_gang_rank_order ON gang_ranks (gang_id, rank_order)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Seed default ranks for gangs that do not have them yet
INSERT INTO gang_ranks (gang_id, rank_name, rank_order, can_invite, can_start_mission)
SELECT g.id, 'Ejer', 1, 1, 1
FROM gangs g
LEFT JOIN gang_ranks r
  ON r.gang_id = g.id AND LOWER(r.rank_name) = 'ejer'
WHERE r.id IS NULL;

INSERT INTO gang_ranks (gang_id, rank_name, rank_order, can_invite, can_start_mission)
SELECT g.id, 'Næstkommanderende', 2, 1, 1
FROM gangs g
LEFT JOIN gang_ranks r
  ON r.gang_id = g.id AND LOWER(r.rank_name) IN ('næstkommanderende','naestkommanderende','nestkommanderende')
WHERE r.id IS NULL;

INSERT INTO gang_ranks (gang_id, rank_name, rank_order, can_invite, can_start_mission)
SELECT g.id, 'Medlem', 3, 0, 0
FROM gangs g
LEFT JOIN gang_ranks r
  ON r.gang_id = g.id AND LOWER(r.rank_name) = 'medlem'
WHERE r.id IS NULL;

-- Normalize rank_order per gang to 1..N
UPDATE gang_ranks SET rank_order = rank_order + 1000;

SET @g := NULL;
SET @r := 0;

UPDATE gang_ranks gr
JOIN (
    SELECT x.id,
           (@r := IF(@g = x.gang_id, @r + 1, 1)) AS new_order,
           (@g := x.gang_id) AS _g
    FROM (
        SELECT id, gang_id, rank_order, rank_name
        FROM gang_ranks
        ORDER BY gang_id, rank_order, id
    ) x
) seq ON seq.id = gr.id
SET gr.rank_order = seq.new_order;

-- Ensure standard permission defaults
UPDATE gang_ranks
SET can_invite = 1,
    can_start_mission = 1
WHERE LOWER(rank_name) IN ('ejer','næstkommanderende','naestkommanderende','nestkommanderende');

UPDATE gang_ranks
SET can_invite = 0,
    can_start_mission = 0
WHERE LOWER(rank_name) = 'medlem';