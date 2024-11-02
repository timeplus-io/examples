-- 
CREATE VIEW IF NOT EXISTS v_fraud_truth_vs_predict_seekto_1h AS 
WITH t AS
  (
    SELECT
        p._tp_time AS ts, p.id AS id, l.is_fraud AS truth
    FROM
        online_payments AS p
    LEFT JOIN online_payments_label AS l ON p.id = l.id
    WHERE
        p._tp_time > (now() - 1h)
  ), p AS
  (
    SELECT
      _tp_time AS ts, id, fraud_detect(to_string(type), amount, previous_amount, time_to_last_transaction, transaction_count_1m, max_transaction_amount_1m, avg_transaction_amount_1m, distinct_transaction_target_count_5m, avg_transaction_count_1d, avg_max_transaction_count_1d) AS predict
    FROM
      mv_fraud_all_features
    SETTINGS
      enable_optimize_predicate_expression = 0, seek_to = '-1h'
  )
SELECT
  t.ts AS ts, t.id AS id, t.truth AS truth, p.predict = 1 AS predict
FROM
  t
INNER JOIN p ON (t.id = p.id);

CREATE MATERIALIZED VIEW IF NOT EXISTS  mv_model_performance
AS
SELECT
  ts, truth, predict, 
  if((truth = true) AND (predict = true), 1, 0) AS TP, 
  if((truth = true) AND (predict = false), 1, 0) AS FP, 
  if((truth = false) AND (predict = false), 1, 0) AS TN, 
  if((truth = false) AND (predict = true), 1, 0) AS FN
FROM
  v_fraud_truth_vs_predict_seekto_1h
STORAGE_SETTINGS index_granularity = 8192, logstore_retention_bytes = -1, logstore_retention_ms = 86400000
TTL to_datetime(_tp_time) + INTERVAL 1 DAY;


-- 
CREATE VIEW IF NOT EXISTS v_realtime_model_performance_5m AS 
SELECT
  window_start, 
  sum(TP + TN) / count() AS accuracy, 
  sum(TP) / sum(TP + FP) AS precision, 
  sum(TP) / sum(TP + FN) AS recall
FROM
  tumble(mv_model_performance, 5m)
WHERE
  _tp_time > earliest_ts()
GROUP BY
  window_start;


CREATE VIEW IF NOT EXISTS v_detected_fraud AS 
SELECT 
  _tp_time, id, fraud_detect(to_string(type), amount, previous_amount, time_to_last_transaction, transaction_count_1m, max_transaction_amount_1m, avg_transaction_amount_1m, distinct_transaction_target_count_5m, avg_transaction_count_1d, avg_max_transaction_count_1d) AS predict
FROM 
  mv_fraud_all_features
WHERE predict = 1
settings enable_optimize_predicate_expression = 0;


-- trend of detected fraud vs ground truth 
CREATE VIEW IF NOT EXISTS v_detected_fraud_vs_ground_truth AS 
WITH gt AS
  (
    SELECT
      window_start, count(*), 'ground_truth' AS label
    FROM
      tumble(table(online_payments_label), 1m)
    WHERE
      (is_fraud = 1) AND (_tp_time > (now() - 1h))
    GROUP BY
      window_start
  ), predict AS
  (
    SELECT
      window_start, count(*), 'prediction' AS label
    FROM
      tumble(table(v_detected_fraud), 1m)
    WHERE
      _tp_time > (now() - 1h)
    GROUP BY
      window_start
  )
SELECT
  *
FROM
  gt
UNION ALL
SELECT
  *
FROM
  predict;

