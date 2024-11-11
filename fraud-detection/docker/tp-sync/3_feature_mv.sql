
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_fraud_all_features
(
  `time` datetime64(3, 'UTC'),
  `id` string,
  `type` enum8('PAYMENT' = 0, 'TRANSFER' = 1, 'CASH_OUT' = 2, 'CASH_IN' = 3, 'DEBIT' = 4),
  `account` string,
  `amount` float64,
  `previous_amount` float64,
  `time_to_last_transaction` int64,
  `transaction_count_1m` uint64,
  `max_transaction_amount_1m` float64,
  `avg_transaction_amount_1m` float64,
  `distinct_transaction_target_count_5m` uint64,
  `avg_transaction_count_1d` float64,
  `avg_max_transaction_count_1d` float64,
  `_tp_time` datetime64(3, 'UTC') DEFAULT now64(3, 'UTC') CODEC(DoubleDelta, ZSTD(1)),
  `_tp_sn` int64 CODEC(Delta(8), ZSTD(1)),
  INDEX _tp_time_index _tp_time TYPE minmax GRANULARITY 32,
  INDEX _tp_sn_index _tp_sn TYPE minmax GRANULARITY 32
) AS
SELECT
  _tp_time AS time, v_fraud_reatime_features.id AS id, v_fraud_reatime_features.type AS type, v_fraud_reatime_features.account_from AS account, v_fraud_reatime_features.amount AS amount, v_fraud_reatime_features.previous_amount AS previous_amount, v_fraud_reatime_features.time_to_last_transaction AS time_to_last_transaction, v_fraud_1m_features.count AS transaction_count_1m, v_fraud_1m_features.max_amount AS max_transaction_amount_1m, v_fraud_1m_features.avg_amount AS avg_transaction_amount_1m, v_fraud_5m_features.target_counts AS distinct_transaction_target_count_5m, v_fraud_1d_features.avg_count AS avg_transaction_count_1d, v_fraud_1d_features.avg_max_amount AS avg_max_transaction_count_1d
FROM
  default.v_fraud_reatime_features
ASOF LEFT JOIN default.v_fraud_1m_features ON (v_fraud_reatime_features.account_from = v_fraud_1m_features.account_from) AND (v_fraud_reatime_features._tp_time >= v_fraud_1m_features.window_start)
ASOF LEFT JOIN default.v_fraud_5m_features ON (v_fraud_reatime_features.account_from = v_fraud_5m_features.account_from) AND (v_fraud_reatime_features._tp_time >= v_fraud_5m_features.window_start)
ASOF LEFT JOIN default.v_fraud_1d_features ON (v_fraud_reatime_features.account_from = v_fraud_1d_features.account_from) AND (v_fraud_reatime_features._tp_time >= v_fraud_1d_features.ts)
SETTINGS 
  keep_versions = 100;