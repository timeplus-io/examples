CREATE STREAM IF NOT EXISTS online_payments
(
  `id` string,
  `type` enum8('PAYMENT' = 0, 'TRANSFER' = 1, 'CASH_OUT' = 2, 'CASH_IN' = 3, 'DEBIT' = 4),
  `amount` float64,
  `account_from` string,
  `old_balance_from` float64,
  `new_balance_from` float64,
  `account_to` string,
  `old_balance_to` float64,
  `new_balance_to` float64
);
CREATE MUTABLE STREAM IF NOT EXISTS online_payments_label
(
  `id` string,
  `is_fraud` bool,
  `type` string,
  `_tp_time` datetime64(3, 'UTC') DEFAULT now64(3, 'UTC') CODEC(DoubleDelta, ZSTD(1))
)
ENGINE = MutableStream(1,1)
PRIMARY KEY id;