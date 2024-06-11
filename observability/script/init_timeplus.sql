CREATE VIEW IF NOT EXISTS default.v_stream_mv_names
(
  `name` string
) AS
SELECT DISTINCT
  name
FROM
  system.stream_metric_log
WHERE
  (type = 'Stream') OR (type = 'MaterializedView') OR (type = 'ExternalStream');

CREATE EXTERNAL STREAM IF NOT EXISTS default.timeplusd_log
(
  `raw` string
)
SETTINGS type = 'log', log_files = 'timeplusd-server.log', log_dir = '/timeplus/logs', timestamp_regex = '^(\\d{4}\\.\\d{2}\\.\\d{2} \\d{2}:\\d{2}:\\d{2}\\.\\d+)', row_delimiter = '(\\d{4}\\.\\d{2}\\.\\d{2} \\d{2}:\\d{2}:\\d{2}\\.\\d+) \\[ \\d+ \\] \\{';