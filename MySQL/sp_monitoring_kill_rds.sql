CREATE DEFINER=`root`@`%` PROCEDURE `monitoring_kill_rds`(
user_rds VARCHAR(150),
duration_time INT)
BEGIN

-- declare NOT FOUND handler
DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
  	GET STACKED DIAGNOSTICS CONDITION 1  @sqlstate = RETURNED_SQLSTATE, @errno = MYSQL_ERRNO, @text = MESSAGE_TEXT;
    INSERT INTO monitoring.history_kill_rds ( execution_date, execution_status, processlist_id, thread_id, user_name,host_name,data_base_name,execution_time,tx_query,sql_state,erro_number,text_information)
         VALUES (NOW(), 'FAILURE','','','','','','','', @sqlstate, @errno, @text);
  END;

 DECLARE EXIT HANDLER FOR 1094
  BEGIN 
  ROLLBACK;
  	GET STACKED DIAGNOSTICS CONDITION 1  @sqlstate = RETURNED_SQLSTATE, @errno = MYSQL_ERRNO, @text = MESSAGE_TEXT;
    INSERT INTO monitoring.history_kill_rds ( execution_date, execution_status, processlist_id, thread_id, user_name,host_name,data_base_name,execution_time,tx_query,sql_state,erro_number,text_information)
         VALUES (NOW(), 'FAILURE','','','','','','','', @sqlstate, @errno, @text);
	  IF @command_kill_code IS NOT NULL THEN
		  PREPARE QUERY FROM @command_kill_code;
		  EXECUTE QUERY;
		  DEALLOCATE PREPARE QUERY;
			  INSERT INTO monitoring.history_kill_rds ( execution_date, execution_status, processlist_id, thread_id, user_name,host_name,data_base_name,execution_time,tx_query,sql_state,erro_number,text_information)            
			  SELECT now(),'Kill executed' as execution_status, ID, THREAD_ID, USER, HOST, DB, execution_time, tx_query,'' as sql_state, '' as erro_number, '' as text_information 
				FROM user_rds_killed;
	  END IF;
  END;
         
SET @cur_now = 0;
		SELECT COUNT(*)
		  INTO @count_rds_kill
		  FROM performance_schema.threads t
		  LEFT OUTER JOIN performance_schema.session_connect_attrs a ON t.processlist_id = a.processlist_id AND (a.attr_name IS NULL OR a.attr_name = 'program_name')
		 WHERE t.TYPE <> 'BACKGROUND'
		   AND t.PROCESSLIST_DB is not null
		   AND t.PROCESSLIST_USER is not null
		   AND CASE WHEN user_rds='ALL' OR user_rds='all' THEN t.PROCESSLIST_USER NOT IN ('root','rdsadmin', 'rdsrepladmin')
					ELSE  FIND_IN_SET (t.PROCESSLIST_USER ,user_rds) END
		   AND t.PROCESSLIST_TIME >=duration_time;
myloop: WHILE @cur_now < (@count_rds_kill) DO
	DROP TEMPORARY TABLE IF EXISTS monitoring.user_rds_killed;
	CREATE TEMPORARY TABLE monitoring.user_rds_killed 
	SELECT 
		t.PROCESSLIST_ID as ID,
		t.THREAD_ID,
		CONCAT('CALL mysql.rds_kill( ', t.PROCESSLIST_ID, ');') as kill_code,
		IF(NAME = 'thread/sql/event_scheduler',
			'event_scheduler',
			t.PROCESSLIST_USER) USER,
		t.PROCESSLIST_HOST HOST,
		t.PROCESSLIST_DB DB,
		SEC_TO_TIME(t.PROCESSLIST_TIME) 'execution_time',
		t.PROCESSLIST_COMMAND COMMAND, 
		t.PROCESSLIST_STATE STATE, 
		coalesce(t.PROCESSLIST_INFO,trx.trx_query) as tx_query,
		a.ATTR_VALUE
	FROM performance_schema.threads t
	 LEFT OUTER JOIN performance_schema.session_connect_attrs a ON t.processlist_id = a.processlist_id AND (a.attr_name IS NULL OR a.attr_name = 'program_name')
	 LEFT OUTER JOIN information_schema.innodb_trx trx on trx.trx_mysql_thread_id=t.PROCESSLIST_ID
	WHERE t.TYPE <> 'BACKGROUND'
      AND t.PROCESSLIST_DB is not null
      AND t.PROCESSLIST_USER is not null
      AND CASE WHEN user_rds='ALL' OR user_rds='all' THEN t.PROCESSLIST_USER NOT IN ('root','rdsadmin', 'rdsrepladmin')
               ELSE  FIND_IN_SET (t.PROCESSLIST_USER ,user_rds) END
	  AND t.PROCESSLIST_TIME >=duration_time
       limit 1;
  
	  SET @command_kill_code=(SELECT kill_code from monitoring.user_rds_killed limit 1);
  
	  IF @command_kill_code IS NOT NULL THEN
		  PREPARE QUERY FROM @command_kill_code;
		  EXECUTE QUERY;
		  DEALLOCATE PREPARE QUERY;
			  INSERT INTO monitoring.history_kill_rds ( execution_date, execution_status, processlist_id, thread_id, user_name,host_name,data_base_name,execution_time,tx_query,sql_state,erro_number,text_information)            
			  SELECT now(),'Kill executed' as execution_status, ID, THREAD_ID, USER, HOST, DB, execution_time, tx_query,'' as sql_state, '' as erro_number, '' as text_information 
				FROM user_rds_killed;
             SELECT *, 'kill executado' as status from monitoring.user_rds_killed;
			END IF;

	  SELECT COUNT(*)
		INTO @count_rds_kill
		FROM performance_schema.threads t
		LEFT OUTER JOIN performance_schema.session_connect_attrs a ON t.processlist_id = a.processlist_id AND (a.attr_name IS NULL OR a.attr_name = 'program_name')
	   WHERE t.TYPE <> 'BACKGROUND'
		 AND t.PROCESSLIST_DB is not null
		 AND t.PROCESSLIST_USER is not null
		 AND CASE WHEN user_rds='ALL' OR user_rds='all' THEN t.PROCESSLIST_USER NOT IN ('root','rdsadmin', 'rdsrepladmin')
				  ELSE  FIND_IN_SET (t.PROCESSLIST_USER ,user_rds) END
		 AND t.PROCESSLIST_TIME >=duration_time;
	IF @cur_now = (@count_rds_kill) THEN 		   
			LEAVE myloop; 
		  END IF;
END WHILE;
 SELECT * FROM monitoring.history_kill_rds
where execution_date between (now() - interval duration_time SECOND) and now();
END
