CREATE TABLE `monitoring`.`history_kill_rds` (
  `id_kill` int NOT NULL AUTO_INCREMENT,
  `execution_date` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `execution_status` varchar(50) DEFAULT NULL,
  `processlist_id` int DEFAULT NULL,
  `thread_id` int DEFAULT NULL,
  `user_name` varchar(100) DEFAULT NULL,
  `host_name` varchar(100) DEFAULT NULL,
  `data_base_name` varchar(100) DEFAULT NULL,
  `execution_time` time DEFAULT NULL,
  `tx_query` longtext,
  `sql_state` varchar(100) DEFAULT NULL,
  `erro_number` varchar(10) DEFAULT NULL,
  `text_information` varchar(200) DEFAULT NULL,
  PRIMARY KEY (`id_kill`),
  KEY `idx_execution_date` (`execution_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

ALTER TABLE `monitoring`.`history_kill_rds` ADD INDEX `idx_execution_date` (`execution_date`);
