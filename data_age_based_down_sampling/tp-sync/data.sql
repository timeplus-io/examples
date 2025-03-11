
-- random stream simulate the source of data
-- one event is generated every second
CREATE RANDOM STREAM IF NOT EXISTS source(value int default rand()%5) 
SETTINGS eps=1;

-- materialized result of timeplus stream data
-- keep on last 1 minute of data
CREATE STREAM IF NOT EXISTS target(value int)
ENGINE = Stream(1,1,rand())
TTL to_datetime(_tp_time) + 1m;

-- MV that read data from source to target
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_reader INTO target
AS
SELECT
    *
FROM
    source;


-- MV that aggregation with 10 seconds granularity
-- keep on last 5 minutes of data
CREATE MATERIALIZED VIEW IF NOT EXISTS down_sampling_target_10s
AS
SELECT
  window_start AS ts, avg(value) AS value
FROM
  tumble(target, 10s)
WHERE
  _tp_time > earliest_ts()
GROUP BY
  window_start
STORAGE_SETTINGS  index_granularity = 8192
TTL to_datetime(ts) + 5m;


-- MV that aggregation with 60 seconds granularity
-- keep on last 1 hour of data
CREATE MATERIALIZED VIEW IF NOT EXISTS down_sampling_target_60s
AS
SELECT
  window_start AS ts, avg(value) AS value
FROM
  tumble(target, 60s)
WHERE
  _tp_time > earliest_ts()
GROUP BY
  window_start
STORAGE_SETTINGS  index_granularity = 8192
TTL to_datetime(ts) + 1h;


-- Unified View on all granularities by age and time range
CREATE VIEW IF NOT EXISTS down_sampling_view
AS
SELECT
  ts as time, value, '10s' as granularity
FROM
  down_sampling_target_10s
WHERE
  time < now() - 1m and time > now() - 5m
SETTINGS seek_to = 'earliest'
UNION ALL
SELECT
  ts as time, value, '60s' as granularity
FROM
  down_sampling_target_60s
WHERE
  time < now() - 5m and time > now() - 1h
SETTINGS seek_to = 'earliest'
UNION ALL
SELECT
  _tp_time as time, value, 'raw' as granularity
FROM
  target
WHERE
  _tp_time > now() - 1m
SETTINGS seek_to = 'earliest';