INSERT IGNORE INTO `jobs` (`name`, `label`) VALUES
('trashman', 'Skraldemand');

INSERT IGNORE INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`) VALUES
('trashman', 0, 'worker', 'Arbejder', 350, '{}', '{}');

INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`) VALUES
('trash_bag', 'Skraldepose', 1, 0, 1),
('scrapmetal', 'Skrotmetal', 1, 0, 1),
('plastic', 'Plastik', 1, 0, 1),
('copper', 'Kobber', 1, 0, 1),
('aluminum', 'Aluminium', 1, 0, 1),
('rubber', 'Gummi', 1, 0, 1);
