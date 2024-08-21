CREATE STREAM IF NOT EXISTS coinbase_tickers
(
  `raw` string
);

CREATE VIEW IF NOT EXISTS v_coinbase_tickers_extracted
(
  `best_ask` float32,
  `best_ask_size` float32,
  `best_bid` float32,
  `best_bid_size` float32,
  `high_24h` float32,
  `last_size` float32,
  `low_24h` float32,
  `open_24h` float32,
  `price` float32,
  `sequence` int64,
  `side` string,
  `trade_id` int64,
  `type` string,
  `volume_24h` float32,
  `volume_30d` float32,
  `product_id` string,
  `_tp_time` datetime64(3)
) AS
SELECT
  cast(raw:best_ask, 'float') AS best_ask, 
  cast(raw:best_ask_size, 'float') AS best_ask_size, 
  cast(raw:best_bid, 'float') AS best_bid, 
  cast(raw:best_bid_size, 'float') AS best_bid_size, 
  cast(raw:high_24h, 'float') AS high_24h, 
  cast(raw:last_size, 'float') AS last_size, 
  cast(raw:low_24h, 'float') AS low_24h, 
  cast(raw:open_24h, 'float') AS open_24h, 
  cast(raw:price, 'float') AS price, 
  cast(raw:sequence, 'bigint') AS sequence, raw:side AS side, 
  cast(raw:trade_id, 'bigint') AS trade_id, raw:type AS type, 
  cast(raw:volume_24h, 'float') AS volume_24h, 
  cast(raw:volume_30d, 'float') AS volume_30d, raw:product_id AS product_id, to_time(raw:time) AS _tp_time
FROM
  coinbase_tickers;

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_coinbase_tickers_extracted
(
  `best_ask` float32,
  `best_ask_size` float32,
  `best_bid` float32,
  `best_bid_size` float32,
  `high_24h` float32,
  `last_size` float32,
  `low_24h` float32,
  `open_24h` float32,
  `price` float32,
  `sequence` int64,
  `side` string,
  `trade_id` int64,
  `type` string,
  `volume_24h` float32,
  `volume_30d` float32,
  `product_id` string,
  `_tp_time` datetime64(3),
  INDEX _tp_time_index _tp_time TYPE minmax GRANULARITY 2
) AS
SELECT
  cast(raw:best_ask, 'float') AS best_ask, cast(raw:best_ask_size, 'float') AS best_ask_size, cast(raw:best_bid, 'float') AS best_bid, cast(raw:best_bid_size, 'float') AS best_bid_size, cast(raw:high_24h, 'float') AS high_24h, cast(raw:last_size, 'float') AS last_size, cast(raw:low_24h, 'float') AS low_24h, cast(raw:open_24h, 'float') AS open_24h, cast(raw:price, 'float') AS price, cast(raw:sequence, 'bigint') AS sequence, raw:side AS side, cast(raw:trade_id, 'bigint') AS trade_id, raw:type AS type, cast(raw:volume_24h, 'float') AS volume_24h, cast(raw:volume_30d, 'float') AS volume_30d, raw:product_id AS product_id, to_time(raw:time) AS _tp_time
FROM
  default.coinbase_tickers
WHERE
  _tp_time > earliest_timestamp();

CREATE VIEW IF NOT EXISTS v_coinbase_btc_ohlc_1m
(
  `time` datetime64(3),
  `open` float32,
  `close` float32,
  `high` float32,
  `low` float32
) AS
SELECT
  window_start as time, 
  earliest(price) AS open, 
  latest(price) AS close, 
  max(price) AS high,
  min(price) AS low
FROM
  tumble(mv_coinbase_tickers_extracted, 1m)
WHERE
  (product_id = 'BTC-USD') AND (_tp_time > (now() - 1h))
GROUP BY
  window_start;

CREATE VIEW IF NOT EXISTS v_btc_1m_engulfing
(
  `time` datetime64(3),
  `b_open` float32,
  `b_close` float32,
  `a_open` float32,
  `a_close` float32,
  `is_bullish_engulfing` bool,
  `is_bearish_engulfing` bool
) AS
WITH OHLC AS
  (
    SELECT
      *
    FROM
      default.v_coinbase_btc_ohlc_1m
    WHERE
      time > (now() - 1h)
  ), TWO_CANDELS AS
  (
    SELECT
      time, open AS b_open, close AS b_close, lag(open) AS a_open, lag(close) AS a_close
    FROM
      OHLC
  )
SELECT
  *, (a_close < a_open) AND (b_close > b_open) AND (b_close > a_open) AND (b_open < a_close) AS is_bullish_engulfing, (a_close > a_open) AND (b_close < b_open) AND (b_close < a_open) AND (b_open > a_close) AS is_bearish_engulfing
FROM
  TWO_CANDELS;


CREATE VIEW IF NOT EXISTS v_btc_1m_ohlc_last_three
(
  `time` datetime64(3),
  `o0` tuple(float32, float32, float32, float32),
  `o1_2` array(tuple(float32, float32, float32, float32)),
  `last_three_events` array(tuple(float32, float32, float32, float32))
) AS
WITH ohlc AS
  (
    SELECT
      time, (open, high, low, close) AS ohlc
    FROM
      default.v_coinbase_btc_ohlc_1m
  )
SELECT
  time, ohlc AS o0, lags(ohlc, 1, 2) AS o1_2, array_concat([o0], o1_2) AS last_three_events
FROM
  ohlc;

CREATE OR REPLACE REMOTE FUNCTION pattern_detect(events array(tuple(float32, float32, float32, float32))) RETURNS array(string) 
URL 'http://cepllm:5001/detect'
AUTH_METHOD 'none';