-- realtime features
CREATE VIEW IF NOT EXISTS v_fraud_reatime_features AS
WITH cte AS
  (
    SELECT 
      _tp_time, 
      id, 
      type, 
      account_from, 
      amount, 
      lag(amount) AS previous_amount, 
      lag(_tp_time) AS previous_transaction_time
    FROM 
      default.online_payments
    WHERE 
      _tp_time > earliest_timestamp()
    PARTITION BY 
      account_from
  )
SELECT 
  _tp_time, 
  id, 
  type, 
  account_from, 
  amount, 
  previous_amount, 
  previous_transaction_time, 
  if(previous_transaction_time > earliest_timestamp(), date_diff('second', previous_transaction_time, _tp_time), 0) AS time_to_last_transaction
FROM 
  cte;

-- near real-time features
CREATE VIEW IF NOT EXISTS v_fraud_1m_features AS
SELECT 
  window_start, 
  account_from, 
  count(*) AS count, 
  max(amount) AS max_amount, 
  min(amount) AS min_amount, 
  avg(amount) AS avg_amount
FROM 
  tumble(default.online_payments, 60s)
WHERE 
  _tp_time > earliest_timestamp()
GROUP BY 
  window_start, account_from;

CREATE VIEW IF NOT EXISTS v_fraud_5m_features AS
SELECT 
  window_start, 
  account_from, 
  count_distinct(account_to) AS target_counts
FROM 
  tumble(default.online_payments, 5m)
WHERE 
  _tp_time > earliest_timestamp()
GROUP BY 
  window_start, account_from;

-- historical features
CREATE VIEW IF NOT EXISTS v_fraud_1d_features AS
WITH agg1d AS
  (
    SELECT 
      window_start, account_from, count(*) AS count, max(amount) AS max_amount
    FROM 
      tumble(default.online_payments, 1d)
    WHERE 
      _tp_time > earliest_timestamp()
    GROUP BY 
      window_start, account_from
  )
SELECT 
  now64() as ts, account_from, avg(count) AS avg_count, avg(max_amount) AS avg_max_amount
FROM 
  agg1d
GROUP BY 
  account_from;