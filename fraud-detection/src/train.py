import os
import json
import pandas as pd
from pycaret.classification import setup, compare_models, save_model

from timeplus import Query, Environment

api_key = os.environ.get("TIMEPLUS_APIKEY")
api_address = os.environ.get("TIMEPLUS_SERVER_URL")
workspace = os.environ.get("TIMEPLUS_WORKSPACE")

# Configure API key and address
environment = Environment().address(api_address).workspace(workspace).apikey(api_key)

sql = '''
SELECT
  *
FROM
  table(mv_fraud_all_features) as f
LEFT JOIN v_latest_labels as l ON f.id = l.id
LIMIT 1000000
'''

query = (
        Query(env=environment).sql(query=sql)
        .batching_policy(10000, 1000)
        .create()
    )

query_header = query.header()
query_result = []
for event in query.result():
    if event.event == "message":
        query_result += json.loads(event.data)

print(f'there are total {len(query_result)}')
query.cancel()

columns = [f['name'] for f in query_header]
df = pd.DataFrame(query_result, columns=columns)
df_train = df[['type', 'amount', 'previous_amount',
               'time_to_last_transaction', 'transaction_count_1m',
               'max_transaction_amount_1m', 'avg_transaction_amount_1m',
               'distinct_transaction_target_count_5m',
               'avg_transaction_count_1d',
               'avg_max_transaction_count_1d', 'is_fraud']]

setup(data=df_train, target='is_fraud', session_id=123)
best_model = compare_models()
save_model(best_model, '/model/fraud_model')
