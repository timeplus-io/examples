CREATE MATERIALIZED VIEW IF NOT EXISTS mv_detected_fraud AS
WITH t AS
  (
    SELECT
        p._tp_time AS ts, p.id AS id, l.is_fraud AS truth
    FROM
        online_payments AS p
    LEFT JOIN online_payments_label AS l ON (p.id = l.id) AND date_diff_within(1s)
    WHERE
        p._tp_time > (now() - 1h)
  ), p AS
  (
    SELECT
      _tp_time AS ts, id, fraud_detect(to_string(type), amount, previous_amount, time_to_last_transaction, transaction_count_1m, max_transaction_amount_1m, avg_transaction_amount_1m, distinct_transaction_target_count_5m, avg_transaction_count_1d, avg_max_transaction_count_1d) AS predict
    FROM
      mv_fraud_all_features
    WHERE
      _tp_time > (now() -1h)
  )
SELECT
  t.ts AS ts, t.id AS id, t.truth AS truth, p.predict != 0 AS predict
FROM
  t
INNER JOIN p ON (t.id = p.id)