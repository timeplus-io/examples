CREATE STREAM mongo_cdc
(
  `raw` string
)
ENGINE = ExternalStream
SETTINGS type = 'kafka', brokers = 'redpanda:29092', topic = 'dbserver1.testdb.testcollection', skip_ssl_cert_check = true