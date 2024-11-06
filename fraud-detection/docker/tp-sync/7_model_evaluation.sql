--
CREATE VIEW IF NOT EXISTS  v_model_performance
AS
SELECT
  ts, truth, predict, 
  if((truth = true) AND (predict = true), 1, 0) AS TP, 
  if((truth = true) AND (predict = false), 1, 0) AS FP, 
  if((truth = false) AND (predict = false), 1, 0) AS TN, 
  if((truth = false) AND (predict = true), 1, 0) AS FN
FROM
  table(mv_detected_fraud);

--
CREATE VIEW IF NOT EXISTS v_model_performance_all
AS 
SELECT
  sum(TP + TN) / count() AS accuracy, 
  sum(TP) / sum(TP + FP) AS precision, 
  sum(TP) / sum(TP + FN) AS recall
FROM
  v_model_performance;

CREATE VIEW IF NOT EXISTS  v_model_performance_5m
AS
SELECT
  window_start, 
  sum(TP + TN) / count() AS accuracy, 
  sum(TP) / sum(TP + FP) AS precision, 
  sum(TP) / sum(TP + FN) AS recall
FROM
  tumble(v_model_performance, ts, 5m)
GROUP BY
  window_start
ORDER BY
  window_start;



