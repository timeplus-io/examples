CREATE STREAM s2s_stream(_index string, host string, source string, sourcetype string, _raw string, fields map(string, string));

CREATE INPUT s2s_input settings type='splunk-s2s', tcp_port=9997, target_stream='s2s_stream';

SELECT * FROM s2s_sink;

CREATE EXTERNAL STREAM http_splunk_t1 (event string)
SETTINGS
type = 'http',
data_format = 'JSONEachRow',
http_header_Authorization='Splunk token12345',
url = 'http://splunk:8088/services/collector/event'

CREATE MATERIALIZED VIEW write_to_splunk INTO http_splunk_t1
AS
SELECT
  _raw AS event
FROM
  s2s_stream
WHERE
  _index = 'default';


CREATE EXTERNAL TABLE s3_audit_logs
(
  `_tp_time` datetime64(3, 'UTC'),
  `_index` string,
  `host` string,
  `source` string,
  `sourcetype` string,
  `_raw` string,
  `fields` map(string, string)
)
SETTINGS
    type = 's3',
    access_key_id = 'minioadmin',
    secret_access_key = 'minioadmin',
    region = 'us-east-1',
    bucket = 'timeplus',
    data_format = 'JSONEachRow',
    endpoint = 'http://minio:9000',
    write_to = 'audit/logs.json',
    use_environment_credentials = false;

CREATE MATERIALIZED VIEW mv_splunk_aduit_logs_to_s3 
INTO s3_audit_logs
AS
SELECT
  _tp_time,
  _index,
  host,
  source,
  sourcetype,
  _raw,
  fields
FROM s2s_stream 
WHERE _index = '_audit';


-- Extract top results from Linux TA
SELECT
  array_join(parsed) as row, _tp_time,
  row[1] as pid,
  row[2] as user,
  row[3] as priority,
  row[4] as nice,
  row[5] as virt,
  row[6] as res,
  row[7] as shr,
  row[8] as status,
  row[9] as pct_cpu,
  row[10] as pct_mem,
  row[11] as cpu_time,
  row[12] as command
FROM
  (
    SELECT
      _tp_time,
      extract_all_groups(_raw, '(\\d+)\\s+(\\w+)\\s+(\\d+)\\s+(\\d+)\\s+(\\d+)\\s+(\\d+)\\s+(\\d+)\\s+(\\w)\\s+([\\d.]+)\\s+([\\d.]+)\\s+([\\d:.]+)\\s+(\\S+)') AS parsed
    FROM
      s2s_stream
    WHERE
      (_index = 'default') AND (_tp_time > (now() - 1d)) AND (source = 'top')
  )

-- extract package information from Linux TA
SELECT
  array_join(packages) AS package, _tp_time,
  trim(package[1]) as name,
  trim(package[2]) as version,
  trim(package[3]) as release,
  trim(package[4]) as arch,
  trim(package[5]) as vendor,
  trim(package[6]) as group_name
FROM
  (
    SELECT
      _tp_time, extract_all_groups(_raw, '(?m)^(\\S+)\\s+(\\S+)\\s+(\\S+)\\s+(\\S+)\\s+(.+?)\\s{2,}([^\n]+)$') AS packages
    FROM
      s2s_stream
    WHERE
      (_index = 'default') AND (_tp_time > (now() - 1d)) AND (source = 'package')
  )