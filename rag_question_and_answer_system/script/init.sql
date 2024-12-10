-- create stream for vector store
CREATE STREAM IF NOT EXISTS vector_store
(
  `name` string,
  `id` string DEFAULT to_string(uuid()),
  `text` string,
  `vector` array(float64),
  `metadata` map(string, string)
);

DROP FUNCTION IF EXISTS embedding;

-- create embedding UDF, udf is stateless, recreate it is OK
CREATE REMOTE FUNCTION embedding(input string) RETURNS string 
URL 'http://udf:5001/embedding'
EXECUTION_TIMEOUT 60000;


DROP FUNCTION IF EXISTS chat;

-- create chat UDF, udf is stateless, recreate it is OK
CREATE REMOTE FUNCTION chat(input string) RETURNS string 
URL 'http://udf:5001/chat'
EXECUTION_TIMEOUT 60000;