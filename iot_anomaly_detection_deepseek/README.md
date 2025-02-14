This exmaple shows how to use python UDF to call DeepSeek-R1 hosted with Ollama to do anomaly detection in real-time.

Here is the quick start guide

1. install and run ollama locally, refer to https://ollama.com/ 
2. run 'ollama pull deepseek-r1' to checkout the deepseek-r1 model locally
3. run 'make start' to start the timeplus in docker
4. run 'make init' to initialize all resources, including demo streams and UDFs
5. login to Timeplus console UI in your browser 'http://localhost:8000', you may need regester new user if it is first time run
6. run following query for the anomaly detection qeury

```sql
SELECT
  window_start, anomaly_detector(ts,value) as anomaly, group_array((ts,value)) as datapoints
FROM
  tumble(sensor, 30s)
GROUP BY
  window_start
```

7. pause/unpause the spike MV to see the how the spike impact the detection result

```sql
SYSTEM PAUSE MATERIALIZED VIEW mv_read_from_senor_spike
SYSTEM UNPAUSE MATERIALIZED VIEW mv_read_from_senor_spike
```