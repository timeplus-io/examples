CREATE DATABASE IF NOT EXISTS cisco_o11y;

CREATE EXTERNAL STREAM IF NOT EXISTS cisco_o11y.asa_logs_stream (
    message string
)
SETTINGS type = 'kafka', brokers = 'redpanda:9092', topic = 'cisco_asa_logs', data_format='JSONEachRow', one_message_per_row=true;


-- Cisco ASA Log Grok Patterns

CREATE VIEW IF NOT EXISTS cisco_o11y.v_asa_logs_parsed_with_predefined_patterns
AS
select
    -- Parse syslog header
    grok(message,'<%{POSINT:priority}>%{SYSLOGTIMESTAMP:timestamp} %{HOSTNAME:device} %%{WORD:facility}-%{INT:severity}-%{INT:event_id}: %{GREEDYDATA:asa_message}') as m,
    
    -- Parse event-specific fields using predefined pattern names
    multi_if(
        m['event_id'] in ('302013', '302014', '302015', '302016'),
        grok(m['asa_message'], '%{CISCOFW302013_302014_302015_302016}'),

        m['event_id'] in ('302020', '302021'),
        grok(m['asa_message'], '%{CISCOFW302020_302021}'),

        m['event_id'] in ('305011'),
        grok(m['asa_message'], '%{CISCOFW305011}'),

        m['event_id'] in ('106015'),
        grok(m['asa_message'], '%{CISCOFW106015}'),

        m['event_id'] in ('106001'),
        grok(m['asa_message'], '%{CISCOFW106001}'),

        m['event_id'] = '106023',
        grok(m['asa_message'], '%{CISCOFW106023}'),
        
        map_cast(['event_id'], [m['event_id']])
    ) as m1
    
from cisco_o11y.asa_logs_stream
where m['event_id'] in ['302013', '302014', '302015', '302016', '302020', '302021', '305011', 
                         '106001', '106023', '106015'];

CREATE EXTERNAL STREAM IF NOT EXISTS cisco_o11y.parsed_asa_logs_stream_timeplus (
    raw string
)
SETTINGS type = 'kafka', brokers = 'redpanda:9092', topic = 'cisco_asa_parsed_timeplus', data_format='RawBLOB';


CREATE MATERIALIZED VIEW IF NOT EXISTS cisco_o11y.mv_asa_logs_parsed
INTO cisco_o11y.parsed_asa_logs_stream_timeplus
AS
select map_update(m, m1) AS raw from cisco_o11y.v_asa_logs_parsed_with_predefined_patterns


-- read from kafka topic parsed by logstash
CREATE EXTERNAL STREAM IF NOT EXISTS cisco_o11y.parsed_asa_logs_stream_logstash (
    raw string
)
SETTINGS type = 'kafka', brokers = 'redpanda:9092', topic = 'cisco_asa_parsed_logstash', data_format='RawBLOB';
