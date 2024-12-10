SELECT
  text, metadata, l2_distance(vector, embedding('how to read kafka data')) AS score
FROM
  table(vector_store)
ORDER BY
  score ASC
LIMIT 3