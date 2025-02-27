CREATE STREAM default.otel
(
  `raw` string
)
ENGINE = ExternalStream
SETTINGS type = 'kafka', brokers = 'redpanda:9092', topic = 'otel-data', security_protocol = 'PLAINTEXT', data_format = 'RawBLOB', skip_ssl_cert_check = 'false', one_message_per_row = 'true'
COMMENT 'otel collected container logs and metrics'