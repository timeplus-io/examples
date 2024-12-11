
This examples shows how to build a LLM based question answer system using
- Timeplus as vector store
- Ollama mxbai-embed-large model as embedding
- Ollama llama3.2:1b as LLM


## Quick Start


- run ollama locally and pull those two models `mxbai-embed-large` and `llama3.2:1b`
- run the docker stack with `docker compose up -d`
- run the onboarding process of timeplus with localhost:8000, create initial user
- setup following environment
    export LLM_BASE_URL=http://localhost:11434/v1
    export TIMEPLUS_HOST=localhost
    export TIMEPLUS_USER=username
    export TIMEPLUS_PASSWORD=password
- download all the orginal timeplus doc from https://tp-solutions.s3.us-west-2.amazonaws.com/timeplus_doc/timeplus_docs.zip, unzip it to folder timeplus_doc
- run 'make index' to index all the documents into Timeplus
- run the following question answer SQL with different questions

```sql
WITH 'what is a streaming query' AS question
SELECT
  array_string_concat(array_reduce('group_array', group_array(text))) AS relevant_docs, 
  concat('Based on following relevant information: ', relevant_docs,' Answer following question : ', question) as prompt,
  chat(prompt) as response
FROM (
  SELECT
    text, l2_distance(vector, embedding(question)) AS score
  FROM
    table(vector_store)
  ORDER BY
    score ASC
  LIMIT 3
)
```