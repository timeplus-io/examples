-- define remote functions
CREATE REMOTE FUNCTION is_ddos(bwd_packet_length_min float64,
  bwd_packet_length_std float64,
  avg_packet_size float64,
  flow_duration float64,
  flow_iat_std float64
) RETURNS bool 
URL 'http://ddos-server:5001/is_ddos'
EXECUTION_TIMEOUT 60000;


-- simulate test network flows
CREATE RANDOM STREAM network(
    bwd_packet_length_min float64 default rand()%7,
    bwd_packet_length_std float64 default rand()%2437,
    avg_packet_size float64 default rand()%1284 + 8,
    flow_duration float64 default rand()%1452333 + 71180,
    flow_iat_std float64 default rand()%564168 + 19104
) SETTINGS eps=0.1;

-- run streaming query to detect ddos
SELECT
  *, is_ddos(bwd_packet_length_min, bwd_packet_length_std, avg_packet_size, flow_duration, flow_iat_std)
FROM
  network



