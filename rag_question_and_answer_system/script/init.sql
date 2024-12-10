-- create stream for vector store
CREATE STREAM IF NOT EXISTS vector_store
(
  `name` string,
  `id` string DEFAULT to_string(uuid()),
  `text` string,
  `vector` array(float64),
  `metadata` map(string, string)
);

-- create embedding UDF
CREATE REMOTE FUNCTION embedding(input string) RETURNS string 
URL 'http://embedding:5001/embedding'
EXECUTION_TIMEOUT 60000;