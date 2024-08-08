CREATE RANDOM STREAM IF NOT EXISTS devices(
  device string default 'device'||to_string(rand()%4),
  temperature float default rand()%1000/10);

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_device_5s AS
  SELECT window_start as ts, device, max(temperature) as max_temperature
  FROM hop(devices, 2s, 5s)
  GROUP BY window_start, device ;