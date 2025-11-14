-- Critical Security Events (Immediate)
CREATE VIEW cisco_o11y.v_alert_critical_events
AS
SELECT
  now64(3) AS alert_time,
  concat('Critical Event: Message ID ', message_id, ' on device ', device_name) AS title,
  concat(
    'Device ', device_name, ' reported a critical event (Severity ', to_string(severity), '). ',
    'Message: ', asa_message
  ) AS description,
  'critical' AS alert_severity,
  [asa_message] AS raw_events
FROM cisco_o11y.flatten_extracted_asa_logs
WHERE severity < 2;

-- Alert 2: Brute Force Detection (5+ failed auth in 5min)
CREATE VIEW cisco_o11y.v_alert_brute_force
AS
SELECT
  window_start as alert_time,
  any(device_name) AS device_name,
  concat('Potential brute force attack on user ', username) AS title,
  concat(
    'Detected ', to_string(count()), ' authentication failures for user "',
    username, '" on AAA server ', any(to_string(aaa_server)), ' in 60 seconds. ',
    'Reasons: ', any(auth_reason)
  ) AS description,
  any(to_string(aaa_server)) AS server,  -- Use AAA server as "source"
  'critical' AS alert_severity,
  username,  -- Use username as "target"
  count() AS event_count,
  group_array(asa_message) AS raw_events,
  'Block or investigate user account - possible credential stuffing or brute force attack' AS recommended_action
FROM tumble(cisco_o11y.flatten_extracted_asa_logs, 1m)
WHERE message_id = '113015'  -- AAA Authentication Rejected
  AND username != ''  -- Ensure username is populated
GROUP BY
  window_start,
  username  -- Group by username being attacked
HAVING count() >= 30
EMIT PERIODIC 15s;

--  DDoS Attack Indicators
CREATE VIEW cisco_o11y.v_alert_ddos
AS
SELECT
  window_start AS alert_time,
  'critical' AS alert_severity,
  concat('Potential DoS attack targeting ', to_string(dst_ip)) AS title,
  concat(
    'Detected ', to_string(event_count), ' connection attempts from ',
    to_string(src_ip_number), ' unique source IPs within 30 seconds. ',
    'This indicates a distributed denial-of-service attack pattern where multiple sources ',
    'are simultaneously flooding the target system. The attack may be attempting to ',
    'exhaust system resources and cause service disruption.'
  ) AS description,
  group_array(src_ip) AS src_ip_list,
  length(src_ip_list) AS src_ip_number,
  dst_ip,
  count() AS event_count,
  'Enable DoS protection and rate limiting on affected interface' AS recommended_action
FROM hop(cisco_o11y.flatten_extracted_asa_logs, 15s, 30s)
WHERE dst_ip IS NOT NULL  -- Only events with destination IP
GROUP BY
  window_start,
  dst_ip
HAVING event_count > 100 AND src_ip_number > 10;   -- 10 unique source IPs send over 100 events in 30s


CREATE VIEW cisco_o11y.v_alerts_all
AS
SELECT
  title,
  description as content,
  alert_severity as severity
FROM
  cisco_o11y.v_alert_critical_events
UNION
SELECT
  title,
  description as content,
  alert_severity as severity
FROM
  cisco_o11y.v_alert_brute_force
UNION
SELECT
  title,
  description as content,
  alert_severity as severity
FROM
  cisco_o11y.v_alert_ddos


-- Alert UDF

CREATE OR REPLACE FUNCTION send_alert_with_webhook(title string, content string, severity string) 
RETURNS string 
LANGUAGE PYTHON AS $$
import json
import requests

def send_alert_with_webhook(title, content, severity):
    results = []
    for title, content, severity in zip(title, content, severity):
        requests.post(
          "http://34.168.13.2/alert",
          data=json.dumps({
              "title": title,
              "message": f"alert with log: {content}",
              "severity": severity
          })
        )
        results.append("OK")
    
    return results
$$

-- Check the alert @ http://34.168.13.2


-- Alert

CREATE ALERT cisco_o11y.event_alert
BATCH 1 EVENTS WITH TIMEOUT 5s
LIMIT 1 ALERTS PER 15s
CALL send_alert_with_webhook
AS 
SELECT
  title,
  content,
  severity
FROM
  cisco_o11y.v_alerts_all;

DROP ALERT IF EXISTS cisco_o11y.event_alert;

