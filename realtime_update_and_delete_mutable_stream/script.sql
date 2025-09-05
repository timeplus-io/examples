CREATE DATABASE IF NOT EXISTS demo;

CREATE STREAM IF NOT EXISTS demo.source (
    `source` string,
    `path` string,
    `value` string,
    is_deleted boolean DEFAULT false
);

CREATE MUTABLE STREAM IF NOT EXISTS demo.target (
    `source` string,
    `path` string,
    `value` string
) PRIMARY KEY (`source`, `path`);

CREATE MATERIALIZED VIEW IF NOT EXISTS demo.mv_update_processor
INTO demo.target
AS
    SELECT
        `source`,
        `path`,
        `value`
    FROM demo.source
    WHERE is_deleted = false;

INSERT INTO demo.source (source, path, value) VALUES 
('s1', '/api/users', '{"status": "success", "count": 150}'),
('s2', '/api/orders', '{"status": "success", "total": 45.99}'),
('s1', '/api/users', '{"status": "error", "message": "timeout"}');

-- query target stream should return two results, s1 path got overriden
SELECT * FROM demo.target;

-- UDF that delete record from target stream triggered by delete event from source stream

CREATE OR REPLACE FUNCTION process_delete(source string, path string, is_deleted boolean) RETURNS string LANGUAGE PYTHON AS $$
from proton_driver import client
host = "localhost"
user = "proton"
password = "timeplus@t+"

proton_client = client.Client(host=host, port=8463, user=user, password=password)

def process_delete(source, path, is_deleted):
    result = []
    for source, path, is_deleted in zip(source, path, is_deleted):
        if is_deleted:
            delete_query = f"DELETE FROM demo.target WHERE source = '{source}' AND path = '{path}'"
            proton_client.execute(delete_query)
            # TODO : handle delete error here
        result.append(f"{source},{path},{is_deleted}")
    return result
$$;
-- mv that handle delete event
CREATE MATERIALIZED VIEW IF NOT EXISTS demo.mv_delete_processor
AS
    SELECT
        process_delete(source, path, is_deleted) AS result
    FROM demo.source;

-- simulate delete event
INSERT INTO demo.source (source, path, is_deleted) VALUES 
('s1', '/api/users', true),


-- query target stream should return one result, s1 path got deleted
SELECT * FROM demo.target;



    