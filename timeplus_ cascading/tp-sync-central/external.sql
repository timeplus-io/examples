DROP VIEW IF EXISTS mv_network;
DROP STREAM IF EXISTS network_edge_1;
DROP STREAM IF EXISTS network_edge_2;
DROP STREAM IF EXISTS network_flow;

CREATE EXTERNAL STREAM IF NOT EXISTS network_edge_1
SETTINGS
    type = 'timeplus',
    hosts = 'timeplus_edge_1',
    db = 'default',
    user = 'proton',
    password = 'timeplus@t+',
    stream = 'network_flow';

CREATE EXTERNAL STREAM IF NOT EXISTS network_edge_2
SETTINGS
    type = 'timeplus',
    hosts = 'timeplus_edge_2',
    db = 'default',
    user = 'proton',
    password = 'timeplus@t+',
    stream = 'network_flow';

CREATE STREAM IF NOT EXISTS network_flow
(
  `time` string,
  `source` ipv4,
  `destination` ipv4,
  `protocol` string,
  `length` int64,
  `edge_name` string
);

CREATE MATERIALIZED VIEW mv_network INTO network_flow
AS
select time, source, destination, protocol, length, 'edge1' as edge_name from network_edge_1
union
select time, source, destination, protocol, length, 'edge2' as edge_name from network_edge_2;



