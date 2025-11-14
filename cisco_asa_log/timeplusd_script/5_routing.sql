
CREATE VIEW cisco_o11y.v_routed_asa_logs
AS
SELECT 
  *,
  -- Simple routing logic on common fields
  multi_if(
    severity <= 2, 'splunk_security',                          -- Critical
    message_id IN ('733102', '733104', '733105', '750004'), 'siem_threat',
    message_id IN ('106023', '106001', '106015'), 'siem_denials',
    message_id LIKE '109%', 'elastic_auth',
    message_id LIKE '302%', 'prometheus_metrics',
    message_id IN ('202010', '702307', '101002', '104500'), 'ops_alerts',
    's3_archive'
  ) AS destination,
  
  multi_if(
    severity = 1, 'ALERT',
    severity = 2, 'CRITICAL',
    severity = 3, 'ERROR',
    severity = 4, 'WARNING',
    severity = 5, 'NOTIFICATION',
    'INFORMATIONAL'
  ) AS severity_label

FROM cisco_o11y.v_dedupped_asa_logs;


CREATE EXTERNAL STREAM cisco_o11y.splunk_t1
(
  `event` string,
  `sourcetype` string DEFAULT 'cisco:asa'
)
ENGINE = ExternalStream
SETTINGS type = 'http', http_header_Authorization = 'Splunk f50aef7d-bd49-4ff3-90f9-d8ac54ecbe37', url = 'http://35.230.87.146:8088/services/collector'
COMMENT 'send message to splunk.demo.timeplus.com';


CREATE MATERIALIZED VIEW IF NOT EXISTS cisco_o11y.mv_asa_logs_to_splunks
INTO cisco_o11y.splunk_t1
AS
SELECT
    json_encode(* except raw_message) AS event
FROM cisco_o11y.v_routed_asa_logs
WHERE destination = 'splunk_security';


CREATE EXTERNAL TABLE cisco_o11y.gcs
(
  `ingestion_time` datetime64(3),
  `log_timestamp` string,
  `device_name` string,
  `severity` nullable(int8),
  `message_id` string,
  `asa_message` string,
  `destination` string,
  `severity_label` string
)
SETTINGS type = 's3', endpoint = 'https://storage.googleapis.com/timeplus-demo', access_key_id = 'key', secret_access_key = 'id', data_format = 'JSONEachRow', write_to = 'cisco_asa/logs.jsonl', s3_min_upload_file_size = 1024, s3_max_upload_idle_seconds = 60


CREATE MATERIALIZED VIEW IF NOT EXISTS cisco_o11y.mv_asa_logs_to_s3
INTO cisco_o11y.gcs
AS
SELECT
  *
FROM
  cisco_o11y.v_routed_asa_logs
WHERE
  destination = 's3_archive'