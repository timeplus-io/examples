
-- search top 3 relevance docs
SELECT
  text, metadata, l2_distance(vector, embedding('what is a streaming query')) AS score
FROM
  table(vector_store)
ORDER BY
  score ASC
LIMIT 3;

-- search top 3 relevance docs and meger them into one text
SELECT
  array_string_concat(array_reduce('group_array', group_array(text))) AS merged_text
FROM (
  SELECT
    text, l2_distance(vector, embedding('what is a streaming query ')) AS score
  FROM
    table(vector_store)
  ORDER BY
    score ASC
  LIMIT 3
)

-- compose the question using RAG and send to LLM
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