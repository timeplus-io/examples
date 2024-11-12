CREATE VIEW IF NOT EXISTS v_realtime_model_performance_alltime AS 
SELECT
  sum(TP + TN) / count() AS accuracy, sum(TP) / sum(TP + FP) AS precision, sum(TP) / sum(TP + FN) AS recall
FROM
  table(v_realtime_model_performance)