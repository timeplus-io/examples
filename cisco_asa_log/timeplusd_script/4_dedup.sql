CREATE VIEW cisco_o11y.v_dedupped_asa_logs
AS
WITH extracted AS (
  SELECT
    ingestion_time,
    log_timestamp,
    device_name,
    severity,
    message_id,
    asa_message,
    -- Extract first IP (source)
    extract(asa_message, 'from ([0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3})') AS src_ip,
    -- Extract second IP (destination) 
    extract(asa_message, 'to ([0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3})') AS dst_ip
  FROM cisco_o11y.v_filtered_asa_logs
)
SELECT
  ingestion_time,
  log_timestamp,
  device_name,
  severity,
  message_id,
  asa_message,
  src_ip,
  dst_ip
FROM dedup(extracted, device_name, message_id, src_ip, dst_ip, 300s, 500000);