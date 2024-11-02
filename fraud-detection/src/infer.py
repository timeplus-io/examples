import os
import json
import pandas as pd
from pycaret.classification import load_model, predict_model
from timeplus import Query, Environment

model = load_model('/model/fraud_model')

api_key = os.environ.get("TIMEPLUS_APIKEY")
api_address = os.environ.get("TIMEPLUS_SERVER_URL")
workspace = os.environ.get("TIMEPLUS_WORKSPACE")

# Configure API key and address
env = Environment().address(api_address).workspace(workspace).apikey(api_key)

sql = '''
SELECT
  *
FROM
  mv_fraud_all_features
WHERE _tp_time > now() -1h
LIMIT 1000
'''

query = (
        Query(env=env).sql(query=sql)
        .create()
    )

query_header = query.header()
columns = [f['name'] for f in query_header]

for event in query.result():
    if event.event == "message":
        query_result = []
        query_result += json.loads(event.data)
        df = pd.DataFrame(query_result, columns=columns)
        df_infer = df[['id', 'type', 'amount', 'previous_amount',
                       'time_to_last_transaction', 'transaction_count_1m',
                       'max_transaction_amount_1m', 'avg_transaction_amount_1m',
                       'distinct_transaction_target_count_5m',
                       'avg_transaction_count_1d', 'avg_max_transaction_count_1d']]

        prediction = predict_model(model, data=df_infer)
        id = prediction['id'].tolist()[0]
        prediction_lable = prediction['prediction_label'].tolist()[0]
        is_fraud = 'fraud' if prediction_lable == 1 else 'not fraud'
        if prediction_lable == 1:
          print(f"transaction {id} is {is_fraud}")
