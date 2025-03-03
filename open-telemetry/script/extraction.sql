
-- metrics extraction
SELECT
 array_join(json_extract_array(scopeMetrics, 'metrics')) AS metrics
FROM
 (
   SELECT
     array_join(json_extract_array(resourceMetrics, 'scopeMetrics')) AS scopeMetrics
   FROM
     (
       SELECT
         array_join(json_extract_array(raw, 'resourceMetrics')) AS resourceMetrics
       FROM
         otel_metrics
       WHERE
         _tp_time > (now() - 1m)
     ) AS l1ResourceMetrics
 ) AS l2ScopeMetrics;

-- logs extraction

SELECT
 array_join(json_extract_array(scopeLogs, 'logRecords')) AS logRecords
FROM
 (
   SELECT
     array_join(json_extract_array(resourceLogs, 'scopeLogs')) AS scopeLogs
   FROM
     (
       SELECT
         array_join(json_extract_array(raw, 'resourceLogs')) AS resourceLogs
       FROM
         otel_logs
       WHERE
         _tp_time > (now() - 3m)
     )
 )