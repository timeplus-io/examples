--
CREATE VIEW IF NOT EXISTS v_fraud_truth_vs_predict_seekto_1h_historical AS 
WITH t AS
  (
    SELECT
      p._tp_time AS ts, p.id AS id, l.is_fraud AS truth
    FROM
      table(online_payments) AS p
    LEFT JOIN table(online_payments_label) AS l ON p.id = l.id
    WHERE
      p._tp_time > (now() - 1h)
  ), p AS
  (
    SELECT
      _tp_time AS ts, id, fraud_detect(to_string(type), amount, previous_amount, time_to_last_transaction, transaction_count_1m, max_transaction_amount_1m, avg_transaction_amount_1m, distinct_transaction_target_count_5m, avg_transaction_count_1d, avg_max_transaction_count_1d) AS predict
    FROM
      table(mv_fraud_all_features)
    WHERE
      _tp_time > (now() - 1h)
  )
SELECT
  t.ts AS ts, t.id AS id, t.truth AS truth, p.predict = 1 AS predict
FROM
  t
INNER JOIN p ON t.id = p.id;

--
CREATE VIEW IF NOT EXISTS  v_model_performance
AS
SELECT
  ts, truth, predict, 
  if((truth = true) AND (predict = true), 1, 0) AS TP, 
  if((truth = true) AND (predict = false), 1, 0) AS FP, 
  if((truth = false) AND (predict = false), 1, 0) AS TN, 
  if((truth = false) AND (predict = true), 1, 0) AS FN
FROM
  v_fraud_truth_vs_predict_seekto_1h_historical;

--
CREATE VIEW IF NOT EXISTS v_model_performance_all
AS 
SELECT
  sum(TP + TN) / count() AS accuracy, 
  sum(TP) / sum(TP + FP) AS precision, 
  sum(TP) / sum(TP + FN) AS recall
FROM
  v_model_performance;

CREATE VIEW IF NOT EXISTS  v_model_performance_5m
AS
SELECT
  window_start, 
  sum(TP + TN) / count() AS accuracy, 
  sum(TP) / sum(TP + FP) AS precision, 
  sum(TP) / sum(TP + FN) AS recall
FROM
  tumble(v_model_performance, ts, 5m)
GROUP BY
  window_start
ORDER BY
  window_start;



