-- NW Jobscreator
-- This resource expects ESX-style tables:
--   - jobs(name, label, whitelisted?)
--   - job_grades(job_name, grade, name, label, salary, skin_male?, skin_female?)
--
-- Boss menu persistence table:

CREATE TABLE IF NOT EXISTS `nw_jobcreator_bossmenus` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `label` VARCHAR(64) NOT NULL DEFAULT 'Boss-menu',
  `job` VARCHAR(32) NOT NULL,
  `min_grade` INT NOT NULL DEFAULT 0,
  `money_min_grade` INT NOT NULL DEFAULT 0,
  `employees_min_grade` INT NOT NULL DEFAULT 0,
  `ui` VARCHAR(16) NOT NULL DEFAULT 'ox_lib',
  `open_type` VARCHAR(16) NOT NULL DEFAULT 'text',
  `x` DOUBLE NOT NULL,
  `y` DOUBLE NOT NULL,
  `z` DOUBLE NOT NULL,
  `radius` DOUBLE NOT NULL DEFAULT 1.5,
  `icon` VARCHAR(64) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `job_idx` (`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
