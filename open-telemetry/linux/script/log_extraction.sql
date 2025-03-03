create stream target_logs (
    time_unix_nano uint64,
    observed_time_unix_nano uint64,
    body_string string,
    log_file_name string,
    stream string,
    extracted_time string
);


create materialized view if not exists extracted_logs
into target_stream as 
select
    json_extract_uint(raw:resourceLogs:0:scopeLogs:0:logRecords:0, 'timeUnixNano') as time_unix_nano,
    json_extract_uint(raw:resourceLogs:0:scopeLogs:0:logRecords:0, 'observedTimeUnixNano') as observed_time_unix_nano,
    json_extract_string(raw:resourceLogs:0:scopeLogs:0:logRecords:0:body, 'stringValue') as body_string,
    json_extract_string(
        array_map(
            x -> tuple_cast(
                json_extract_string(x, 'value.stringValue') as log_file_name
            ),
            json_extract_array(raw:resourceLogs:0:scopeLogs:0:logRecords:0, 'attributes')
        ),
        'log.file.name'
    ) as log_file_name,
    json_extract_string(
        array_map(
            x -> tuple_cast(
                json_extract_string(x, 'value.stringValue') as stream
            ),
            json_extract_array(raw:resourceLogs:0:scopeLogs:0:logRecords:0, 'attributes')
        ),
        'stream'
    ) as stream,
    json_extract_string(
        array_map(
            x -> tuple_cast(
                json_extract_string(x, 'value.stringValue') as extracted_time
            ),
            json_extract_array(raw:resourceLogs:0:scopeLogs:0:logRecords:0, 'attributes')
        ),
        'time'
    ) as extracted_time;
