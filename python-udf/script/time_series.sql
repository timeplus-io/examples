SELECT
  latest(date) AS lt, latest(number) AS lv, forecast_agg(date, to_float64(number)) as forecast
FROM
  v_passenger_replay
EMIT PERIODIC 500ms;

-- transform for visualization
WITH forecast AS
  (
    SELECT
      latest(date) AS lt, latest(number) AS lv, forecast_agg(date, to_float64(number)) AS forecast
    FROM
      v_passenger_replay
    EMIT STREAM PERIODIC 500ms  -- emit every 500ms to update the forecast
  )
SELECT
  now() AS time, to_time(lt) AS t, lv, array_join([(lv, 'truth'), (forecast, 'forecast')]) AS reshape, reshape.1 AS value, reshape.2 AS lable
FROM
  forecast