DROP VIEW IF EXISTS mv_read_from_senor_normal;
DROP VIEW IF EXISTS mv_read_from_senor_spike;

DROP STREAM IF EXISTS normal_sensor_source;
DROP STREAM IF EXISTS spike_sensor_source;

DROP STREAM IF EXISTS sensor;

CREATE RANDOM STREAM normal_sensor_source
(
  `ts` datetime DEFAULT now(),
  `value` float64 DEFAULT round(rand_normal(22, 0.01),2)
)
SETTINGS eps = 1;

CREATE RANDOM STREAM spike_sensor_source
(
  `ts` datetime DEFAULT now(),
  `value` float64 DEFAULT round(rand_normal(50, 1),2)
)
SETTINGS eps = 0.1;


CREATE STREAM sensor
(
  `ts` datetime ,
  `value` float64
);

CREATE MATERIALIZED VIEW mv_read_from_senor_normal INTO sensor
AS
SELECT
  ts, value
FROM
  normal_sensor_source;

CREATE MATERIALIZED VIEW mv_read_from_senor_spike INTO sensor
AS
SELECT
  ts, value
FROM
  spike_sensor_source;
