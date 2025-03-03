CREATE STREAM default.otel_logs
(
  `raw` string
)
ENGINE = ExternalStream
SETTINGS type = 'kafka', brokers = 'redpanda:9092', topic = 'otel-logs', security_protocol = 'PLAINTEXT', data_format = 'RawBLOB', skip_ssl_cert_check = 'false', one_message_per_row = 'true'
COMMENT 'otel collected container logs';

CREATE STREAM default.otel_metrics
(
  `raw` string
)
ENGINE = ExternalStream
SETTINGS type = 'kafka', brokers = 'redpanda:9092', topic = 'otel-metrics', security_protocol = 'PLAINTEXT', data_format = 'RawBLOB', skip_ssl_cert_check = 'false', one_message_per_row = 'true'
COMMENT 'otel collected container metrics';