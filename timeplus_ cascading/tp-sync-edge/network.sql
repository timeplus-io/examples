DROP VIEW IF EXISTS mv_network;
DROP STREAM IF EXISTS network_flow_source;
DROP STREAM IF EXISTS network_flow;

CREATE RANDOM STREAM network_flow_source
(
  `time` string default to_string(now()),
  `source` ipv4,
  `destination` ipv4,
  `protocol` string default if(rand()%2=0,'TCP','UDP'),
  `length` int64 default rand()%1000
) SETTINGS eps=100;

CREATE STREAM network_flow
(
  `time` string,
  `source` ipv4,
  `destination` ipv4,
  `protocol` string,
  `length` int64
);

CREATE MATERIALIZED VIEW mv_network INTO network_flow
AS
SELECT
  *
FROM
  network_flow_source;

