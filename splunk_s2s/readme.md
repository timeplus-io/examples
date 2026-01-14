1. Run `docker compose up`
2. Login to Spunk HF (localhost 8001 admin:Password!), add forward server `timeplus:9997`
3. Install Unix TA on HF, config some log files to collect
4. On Splunk Enterprise (localhost 8000 admin:Password!), config the HEC input, disable https
5. On Timeplus (localhost:8002), create resources through timeplus.sql for the logs processing pipeline
6. on Splunk Enterprise (localhost 8000 admin:Password!), search the index data from Timeplus `index = main`