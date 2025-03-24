CREATE TABLE IF NOT EXISTS `deaths` 
(
    `death_index` INT UNSIGNED NOT NULL,
    `death_time` INT UNSIGNED NOT NULL,
    `victim_id` INT UNSIGNED NOT NULL,
    `victim_role` ENUM ('innocent', 'traitor', 'detective') NOT NULL,
    `attacker_id` INT UNSIGNED NOT NULL,
    `attacker_role` ENUM ('innocent', 'traitor', 'detective') NOT NULL,
    `last_gun_fire` INT UNSIGNED NOT NULL,
    `round` INT UNSIGNED NOT NULL,
	PRIMARY KEY (`death_index`),
	UNIQUE `death_id` (`death_time`, `victim_id`),
    INDEX (`victim_id`),
    INDEX (`attacker_id`)
)
ENGINE = InnoDB;

-- Db_InsertDeath
INSERT INTO `deaths` (`death_index`, `death_time`, `victim_id`, `victim_role`, `attacker_id`, `attacker_role`, `last_gun_fire`, `round`) VALUES ('%d', '%d', '%d', '%s', '%d', '%s', '%d', '%d');
