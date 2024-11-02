FROM pycaret/slim

WORKDIR /timeplus
ADD ./requirements.txt /timeplus
RUN pip3 install -r requirements.txt
ADD ./transaction.py /timeplus/transaction.py
ADD ./train.py /timeplus/train.py
ADD ./infer.py /timeplus/infer.py
ADD ./app.py /timeplus/app.py

ADD /model/fraud_model.pkl /timeplus/fraud_model.pkl

#ENTRYPOINT [ "python3" ]
ENTRYPOINT ["uvicorn", "app:app", "--host", "0.0.0.0", "--http", "h11"]