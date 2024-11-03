CREATE OR REPLACE REMOTE FUNCTION fraud_detect(type string, amount float64, previous_amount float64, time_to_last_transaction int32, transaction_count_1m int32, max_transaction_amount_1m float64, avg_transaction_amount_1m float64, distinct_transaction_target_count_5m int32, avg_transaction_count_1d float64, avg_max_transaction_count_1d float64) RETURNS int32 
URL 'http://fraud-detector:8000/predict'
AUTH_METHOD 'none'
EXECUTION_TIMEOUT 20000