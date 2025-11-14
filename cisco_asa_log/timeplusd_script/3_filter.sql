CREATE VIEW cisco_o11y.v_sampled_asa_logs
AS
SELECT *
FROM cisco_o11y.parsed_asa_logs
WHERE severity <= 5 OR (rand()/ 4294967296.0) < 0.01 -- Keep security-relevant events OR 1% sample


CREATE VIEW cisco_o11y.v_filtered_asa_logs
AS
SELECT *
FROM cisco_o11y.v_sampled_asa_logs
WHERE   
  -- Always keep critical messages
  message_id IN (
    '106023', '106001', '106015',  -- Denials
    '733102', '733104', '733105',  -- Threats
    '750004', '108003', '106022',  -- Security
    '202010', '702307',            -- Exhaustion
    '101002', '104500',            -- Failover
    '302013', '302014'             -- Connections
  )
  
  -- Drop noise
  AND NOT (
    message_id IN ('718012', '718015', '718019', '718021', '718023')
  );



