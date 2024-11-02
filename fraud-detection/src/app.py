from typing import List
from fastapi import FastAPI
from pydantic import BaseModel

import pandas as pd
from pycaret.classification import load_model, predict_model

model = load_model('fraud_model')
app = FastAPI()


class PredictItem(BaseModel):
    type: List[str]
    amount: List[float]
    previous_amount: List[float]
    time_to_last_transaction: List[int]
    transaction_count_1m: List[int]
    max_transaction_amount_1m: List[float]
    avg_transaction_amount_1m: List[float]
    distinct_transaction_target_count_5m: List[int]
    avg_transaction_count_1d: List[int]
    avg_max_transaction_count_1d: List[int]


@app.get("/")
def info():
    return {"info": "timeplus fraud detection server"}


@app.post("/predict")
def predict(item: PredictItem):
    data = []
    length = len(item.type)
    for i in range(length):
        row = [item.type[i], item.amount[i],
               item.previous_amount[i], item.time_to_last_transaction[i],
               item.transaction_count_1m[i], item.max_transaction_amount_1m[i],
               item.avg_transaction_amount_1m[i],
               item.distinct_transaction_target_count_5m[i],
               item.avg_transaction_count_1d[i],
               item.avg_max_transaction_count_1d[i]
               ]
        data.append(row)

    cols = ['type', 'amount', 'previous_amount',
            'time_to_last_transaction', 'transaction_count_1m',
            'max_transaction_amount_1m', 'avg_transaction_amount_1m',
            'distinct_transaction_target_count_5m', 'avg_transaction_count_1d',
            'avg_max_transaction_count_1d']

    df_infer = pd.DataFrame(data, columns=cols)
    prediction = predict_model(model, data=df_infer)
    prediction_lable = prediction['prediction_label'].tolist()

    return {"result": prediction_lable}
