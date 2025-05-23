--
CREATE VIEW IF NOT EXISTS  v_realtime_model_performance
AS
SELECT
  _tp_time, truth, predict, 
  if((truth = true) AND (predict = true), 1, 0) AS TP, 
  if((truth = true) AND (predict = false), 1, 0) AS FP, 
  if((truth = false) AND (predict = false), 1, 0) AS TN, 
  if((truth = false) AND (predict = true), 1, 0) AS FN
FROM
  mv_detected_fraud
WHERE
  _tp_time > earliest_ts();


-- 
CREATE VIEW IF NOT EXISTS v_realtime_model_performance_5m AS 
SELECT
  window_start, 
  sum(TP + TN) / count() AS accuracy, 
  sum(TP) / sum(TP + FP) AS precision, 
  sum(TP) / sum(TP + FN) AS recall
FROM
  tumble(v_realtime_model_performance, 5m)
WHERE
  window_start > earliest_ts()
GROUP BY
  window_start;

CREATE VIEW IF NOT EXISTS v_realtime_model_performance_1m AS 
SELECT
  window_start, 
  sum(TP + TN) / count() AS accuracy, 
  sum(TP) / sum(TP + FP) AS precision, 
  sum(TP) / sum(TP + FN) AS recall
FROM
  tumble(v_realtime_model_performance, 1m)
WHERE
  window_start > earliest_ts()
GROUP BY
  window_start;


CREATE VIEW IF NOT EXISTS v_detected_fraud AS 
SELECT 
  _tp_time, id, fraud_detect(to_string(type), amount, previous_amount, time_to_last_transaction, transaction_count_1m, max_transaction_amount_1m, avg_transaction_amount_1m, distinct_transaction_target_count_5m, avg_transaction_count_1d, avg_max_transaction_count_1d) AS predict
FROM 
  mv_fraud_all_features
WHERE predict = 1;


-- trend of detected fraud vs ground truth 
CREATE VIEW IF NOT EXISTS v_detected_fraud_vs_ground_truth AS 
WITH label AS
  (
    SELECT
      *
    FROM
      online_payments_label
    WHERE
      _tp_time > (now() - 1h)
    settings enforce_append_only=1
  ), gt AS
  (
    SELECT
      window_start, count(*), 'ground_truth' AS label
    FROM
      tumble(label, 1m)
    WHERE
      is_fraud = 1
    GROUP BY
      window_start
  ), predict AS
  (
    SELECT
      window_start, count(*), 'prediction' AS label
    FROM
      tumble(v_detected_fraud, 1m)
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