import os
from pprint import pprint
import random
import numpy as np
import time
import uuid
import click
import requests

from timeplus import Stream, View, Environment
from proton_driver import connect

from decimal import Decimal, ROUND_HALF_UP

# configure timeplus
api_key = os.environ.get("TIMEPLUS_APIKEY")
api_address = os.environ.get("TIMEPLUS_SERVER_URL")
timeplus_user = os.environ.get("TIMEPLUS_USERNAME") or "proton"
timeplus_password = os.environ.get("TIMEPLUS_PASSWORD") or "timeplus@t+"
timeplus_host = os.environ.get("TIMEPLUS_HOST") or "localhost"

env = None
proton_ingest_url = f'http://{timeplus_host}:3218/proton/v1/ingest/streams'

ddl_v_fraud_reatime_features = '''WITH cte AS
  (
    SELECT
      _tp_time,
      id,
      type,
      account_from,
      amount,
      lag(amount) AS previous_amount,
      lag(_tp_time) AS previous_transaction_time
    FROM
      default.online_payments
    WHERE
      _tp_time > earliest_timestamp()
    PARTITION BY
      account_from
  )
SELECT
  _tp_time,
  id,
  type,
  account_from,
  amount,
  previous_amount,
  previous_transaction_time,
  if(previous_transaction_time > earliest_timestamp(), date_diff('second', previous_transaction_time, _tp_time), 0) AS time_to_last_transaction
FROM
  cte'''

ddl_v_fraud_1m_features = '''SELECT
  window_start,
  account_from,
  count(*) AS count,
  max(amount) AS max_amount,
  min(amount) AS min_amount,
  avg(amount) AS avg_amount
FROM
  tumble(default.online_payments, 60s)
WHERE
  _tp_time > earliest_timestamp()
GROUP BY
  window_start, account_from'''

ddl_v_fraud_5m_features = '''SELECT
  window_start,
  account_from,
  count_distinct(account_to) AS target_counts
FROM
  tumble(default.online_payments, 5m)
WHERE
  _tp_time > earliest_timestamp()
GROUP BY
  window_start, account_from'''


ddl_v_fraud_1d_features = '''WITH agg1d AS
  (
    SELECT
      window_start as ts, account_from, count(*) AS count, max(amount) AS max_amount
    FROM
      tumble(default.online_payments, 1d)
    WHERE
      _tp_time > earliest_timestamp()
    GROUP BY
      window_start, account_from
  )
SELECT
  window_start as ts, account_from, avg(count) AS avg_count, avg(max_amount) AS avg_max_amount
FROM
  tumble(agg1d, ts, 7d)
GROUP BY
  window_start, account_from'''

ddl_mv_fraud_all_features = '''SELECT
  _tp_time AS time,
  v_fraud_reatime_features.id AS id,
  v_fraud_reatime_features.type AS type,
  v_fraud_reatime_features.account_from AS account,
  v_fraud_reatime_features.amount AS amount,
  v_fraud_reatime_features.previous_amount AS previous_amount,
  v_fraud_reatime_features.time_to_last_transaction AS time_to_last_transaction,
  v_fraud_1m_features.count AS transaction_count_1m,
  v_fraud_1m_features.max_amount AS max_transaction_amount_1m,
  v_fraud_1m_features.avg_amount AS avg_transaction_amount_1m,
  v_fraud_5m_features.target_counts AS distinct_transaction_target_count_5m,
  v_fraud_1d_features.avg_count AS avg_transaction_count_1d,
  v_fraud_1d_features.avg_max_amount AS avg_max_transaction_count_1d
FROM
  v_fraud_reatime_features
ASOF LEFT JOIN v_fraud_1m_features ON (v_fraud_reatime_features.account_from = v_fraud_1m_features.account_from) AND (v_fraud_reatime_features._tp_time >= v_fraud_1m_features.window_start)
ASOF LEFT JOIN v_fraud_5m_features ON (v_fraud_reatime_features.account_from = v_fraud_5m_features.account_from) AND (v_fraud_reatime_features._tp_time >= v_fraud_5m_features.window_start)
ASOF LEFT JOIN v_fraud_1d_features ON (v_fraud_reatime_features.account_from = v_fraud_1d_features.account_from) AND (v_fraud_reatime_features._tp_time >= v_fraud_1d_features.ts)
SETTINGS
  keep_versions = 100'''

ddl_v_fraud_truth_vs_predict_seekto_1h = '''WITH t AS
  (
    SELECT 
      p._tp_time AS ts, p.id AS id, l.is_fraud AS truth
    FROM 
      online_payments AS p
    LEFT JOIN changelog(online_payments_label, id) AS l ON p.id = l.id
    settings seek_to = '-1h'
  ),
p as (
  SELECT 
  _tp_time as ts, id, fraud_detect(to_string(type), amount, previous_amount, time_to_last_transaction, transaction_count_1m, max_transaction_amount_1m, avg_transaction_amount_1m, distinct_transaction_target_count_5m, avg_transaction_count_1d, avg_max_transaction_count_1d) AS predict
FROM 
  mv_fraud_all_features
settings enable_optimize_predicate_expression = 0, seek_to = '-1h'
)
SELECT 
  t.ts as ts, t.id as id, t.truth as truth, (p.predict = 1) as predict
FROM 
  t join p on t.id = p.id and date_diff_within(1m, t.ts, p.ts)
'''

ddl_v_fraud_model_performance = '''with metrics as (
SELECT 
  ts, truth, predict, 
  if((truth = true) AND (predict = true), 1, 0) AS TP,
  if((truth = true) AND (predict = false), 1, 0) AS FP,
  if((truth = false) AND (predict = false), 1, 0) AS TN,
  if((truth = false) AND (predict = true), 1, 0) AS FN
FROM 
  v_fraud_truth_vs_predict_seekto_1h
)
select window_start,  sum(TP+TN) / count() as accuracy , sum(TP)/ sum(TP + FP) as precision , sum(TP)/ sum(TP + FN) as recall  from tumble(metrics, ts, 5m) group by window_start
'''

ddl_v_detected_fraud = '''SELECT 
  _tp_time, id, fraud_detect(to_string(type), amount, previous_amount, time_to_last_transaction, transaction_count_1m, max_transaction_amount_1m, avg_transaction_amount_1m, distinct_transaction_target_count_5m, avg_transaction_count_1d, avg_max_transaction_count_1d) AS predict
FROM 
  mv_fraud_all_features
WHERE predict = 1
settings enable_optimize_predicate_expression = 0
'''

ddl_v_latest_labels = '''WITH ordered_label AS
  (
    SELECT
      *
    FROM
      table(default.online_payments_label)
    ORDER BY
      _tp_time ASC
  )
SELECT
  id, latest(is_fraud) AS is_fraud
FROM
  ordered_label
GROUP BY
  id'''

def clean_timeplus():
    try:
        (
            View(env=env)
            .name('v_fraud_model_performance')
            .delete()
        )
        pprint(f"v_fraud_model_performance deleted")
    except Exception as e:
        print(e)

    try:
        (
            View(env=env)
            .name('v_fraud_truth_vs_predict_seekto_1h')
            .delete()
        )
        pprint(f"v_fraud_truth_vs_predict_seekto_1h deleted")
    except Exception as e:
        print(e)

    try:
        (
            View(env=env)
            .name('v_detected_fraud')
            .delete()
        )
        pprint(f"v_detected_fraud deleted")
    except Exception as e:
        print(e)

    try:
        (
            View(env=env)
            .name('mv_fraud_all_features')
            .delete()
        )
        pprint(f"mv_fraud_all_features deleted")
    except Exception as e:
        print(e)

    try:
        (
            View(env=env)
            .name('v_fraud_reatime_features')
            .delete()
        )
        pprint(f"v_fraud_reatime_features deleted")
    except Exception as e:
        print(e)

    try:
        (
            View(env=env)
            .name('v_fraud_1m_features')
            .delete()
        )
        pprint(f"v_fraud_1m_features deleted")
    except Exception as e:
        print(e)

    try:
        (
            View(env=env)
            .name('v_fraud_5m_features')
            .delete()
        )
        pprint(f"v_fraud_5m_features deleted")
    except Exception as e:
        print(e)

    try:
        (
            View(env=env)
            .name('v_fraud_1d_features')
            .delete()
        )
        pprint(f"v_fraud_1d_features deleted")
    except Exception as e:
        print(e)

    try:
        (
            Stream(env=env)
            .name("online_payments")
            .delete()
        )
        pprint(f"online_payments deleted")
    except Exception as e:
        print(e)

    try:
        (
            View(env=env)
            .name('v_latest_labels')
            .delete()
        )
        pprint(f"v_latest_labels deleted")
    except Exception as e:
        print(e)

    try:
        (
            Stream(env=env)
            .name("online_payments_label")
            .delete()
        )
        pprint(f"online_payments_label deleted")
    except Exception as e:
        print(e)

def init_timeplus():
    global env
    if api_key and api_address:
        try:
            env = Environment().address(api_address).apikey(api_key)
        except:
            print("failed to create timeplus cloud env")
            exit(1)
    else:
        api_address = f"http://{timeplus_host}:8000/local"
        try:
            env = Environment().address(api_address).username(timeplus_user).password(timeplus_user)
        except Exception as e:
            print(f"failed to create timeplus enterprise env, {e}")
            exit(1)

    try:
        (
            Stream(env=env)
            .name("online_payments")
            .column("id", "string")
            .column("type", "enum('PAYMENT' = 0, 'TRANSFER' = 1, 'CASH_OUT' = 2, 'CASH_IN' = 3, 'DEBIT' = 4)")
            .column("amount", "float64")
            .column("account_from", "string")
            .column("old_balance_from", "float64")
            .column("new_balance_from", "float64")
            .column("account_to", "string")
            .column("old_balance_to", "float64")
            .column("new_balance_to", "float64")
            .create()
        )
        pprint(f"online_payments created")
    except Exception as e:
        pprint(e)

    try:
        (
            Stream(env=env).name("online_payments_label")
            .column("id", "string")
            .column("is_fraud", "bool")
            .column("type", "string")
            .create()
        )
        pprint(f"online_payments_label created")
    except Exception as e:
        pprint(e)

    try:
        (
            View(env=env)
            .name('v_fraud_reatime_features')
            .query(ddl_v_fraud_reatime_features)
            .create()
        )
        pprint(f"v_fraud_reatime_features created")
    except Exception as e:
        pprint(e)

    try:
        (
            View(env=env)
            .name('v_fraud_1m_features')
            .query(ddl_v_fraud_1m_features)
            .create()
        )
        pprint(f"v_fraud_1m_features created")
    except Exception as e:
        pprint(e)

    try:
        (
            View(env=env)
            .name('v_fraud_5m_features')
            .query(ddl_v_fraud_5m_features)
            .create()
        )
        pprint(f"v_fraud_5m_features created")
    except Exception as e:
        pprint(e)

    try:
        (
            View(env=env)
            .name('v_fraud_1d_features')
            .query(ddl_v_fraud_1d_features)
            .create()
        )
        pprint(f"v_fraud_1d_features created")
    except Exception as e:
        pprint(e)

    try:
        (
            View(env=env)
            .name('mv_fraud_all_features')
            .materialized(True)
            .query(ddl_mv_fraud_all_features)
            .create()
        )
        pprint(f"mv_fraud_all_features created")
    except Exception as e:
        pprint(e)

    try:
        (
            View(env=env)
            .name('v_detected_fraud')
            .query(ddl_v_detected_fraud)
            .create()
        )
        pprint(f"v_detected_fraud created")
    except Exception as e:
        pprint(e)

    try:
        (
            View(env=env)
            .name('v_fraud_truth_vs_predict_seekto_1h')
            .query(ddl_v_fraud_truth_vs_predict_seekto_1h)
            .create()
        )
        pprint(f"v_fraud_truth_vs_predict_seekto_1h created")
    except Exception as e:
        pprint(e)

    try:
        (
            View(env=env)
            .name('v_fraud_model_performance')
            .query(ddl_v_fraud_model_performance)
            .create()
        )
        pprint(f"v_fraud_model_performance created")
    except Exception as e:
        pprint(e)

    try:
        (
            View(env=env)
            .name('v_latest_labels')
            .query(ddl_v_latest_labels)
            .create()
        )
        pprint(f"ddl_v_latest_labels created")
    except Exception as e:
        pprint(e)


def init_proton():
    

    ddl_payment = '''CREATE STREAM IF NOT EXISTS online_payments(
        `id` string,
        `type` enum8('PAYMENT' = 0, 'TRANSFER' = 1, 'CASH_OUT' = 2, 'CASH_IN' = 3, 'DEBIT' = 4),
        `amount` float64,
        `account_from` string,
        `old_balance_from` float64,
        `new_balance_from` float64,
        `account_to` string,
        `old_balance_to` float64,
        `new_balance_to` float64
    )'''

    ddl_label = '''CREATE MUTABLE STREAM IF NOT EXISTS online_payments_label
(
  `id` string,
  `is_fraud` bool,
  `type` string,
  `_tp_time` datetime64(3, 'UTC') DEFAULT now64(3, 'UTC') CODEC(DoubleDelta, ZSTD(1))
)
ENGINE = MutableStream(1,1)
PRIMARY KEY id;'''

    with connect(f"proton://{timeplus_user}:{timeplus_password}@{timeplus_host}:8463/default") as conn:
        with conn.cursor() as cursor:
            cursor.execute(ddl_payment)
            cursor.execute(ddl_label)


def generate_random_numbers(size):
    u = np.random.uniform(0, 1, size)
    epsilon = 1e-10  # Small constant to avoid log(1)
    adjusted_values = 1 - u + epsilon
    adjusted_values[adjusted_values <= 0] = epsilon  # Replace values <= 0 with epsilon
    return -np.log(adjusted_values) / 0.1


size = 10000
random_numbers = generate_random_numbers(size)


def my_round(value, digit=2):
    decimal_value = Decimal(str(round(value, 2)))
    precision = Decimal('0.01')  # Set precision as a Decimal
    rounded_value = (decimal_value / precision).quantize(Decimal('1.'), rounding=ROUND_HALF_UP) * precision

    return float(rounded_value)


class PaymentSimulator():
    def __init__(self, number_of_account=10, number_of_m_account=10, interval=1, batch=3, fraud_rate=0.05, target='proton'):
        self.payment_types = ['PAYMENT', 'TRANSFER', 'CASH_OUT', 'DEBIT', 'CASH_IN']
        self.payment_types_weights = [0.4, 0.3, 0.1, 0.1, 0.1]
        self.number_of_account = number_of_account
        self.number_of_m_account = number_of_m_account
        self.interval = interval
        self.batch = batch
        self.transaction_queue = []
        self.accounts = []
        self.maccounts = []
        self.fraud_rate = fraud_rate
        self.fraud_threshold = 1000
        self.init_accounts()
        self.target = target

    def init_accounts(self):
        for i in range(self.number_of_account):
            account = {}
            random_number = random.randint(10**11, 10**12 - 1)
            account['id'] = f'C{random_number}'
            account['amount'] = my_round(random.choice(random_numbers)) + self.fraud_threshold
            self.accounts.append(account)

        for i in range(self.number_of_m_account):
            account = {}
            random_number = random.randint(10**11, 10**12 - 1)
            account['id'] = f'M{random_number}'
            self.maccounts.append(account)

    def run_transfer(self):
        account_from = random.choice(self.accounts)
        account_to = random.choice(self.accounts)
        amount = round(random.uniform(0, account_from['amount']), 2)
        if amount == 0:
            return
        old_balance_from = account_from['amount']
        old_balance_to = account_to['amount']
        new_balance_from = my_round(account_from['amount'] - amount, 2)
        new_balance_to = my_round(account_to['amount'] + amount, 2)

        account_from['amount'] = new_balance_from
        account_to['amount'] = new_balance_to

        #print(f"transfer {amount} from {account_from['id']} to {account_to['id'] }")

        transaction_data = [str(uuid.uuid4()),
                            'TRANSFER',
                            amount,
                            account_from['id'],
                            old_balance_from,
                            new_balance_from,
                            account_to['id'],
                            old_balance_to,
                            new_balance_to]
        self.transaction_queue.append(transaction_data)

    def run_payment(self):
        account_from = random.choice(self.accounts)
        amount = round(random.uniform(0, account_from['amount']), 2)
        if amount == 0:
            return
        old_balance_from = account_from['amount']
        old_balance_to = 0.00
        new_balance_from = my_round(account_from['amount'] - amount, 2)
        new_balance_to = 0.00
        account_from['amount'] = new_balance_from
        account_to = random.choice(self.maccounts)
        #print(f"payment {amount} from {account_from['id']} to {account_to['id']} ")

        transaction_data = [str(uuid.uuid4()),
                            'PAYMENT',
                            amount,
                            account_from['id'],
                            old_balance_from,
                            new_balance_from,
                            account_to['id'],
                            old_balance_to,
                            new_balance_to]
        self.transaction_queue.append(transaction_data)

    def run_cash_in(self):
        account = random.choice(self.accounts)
        amount = my_round(random.uniform(0, 10000), 2)
        if amount == 0:
            return
        old_balance_from = account['amount']
        old_balance_to = 0.00
        new_balance_from = my_round(account['amount'] + amount, 2)
        new_balance_to = 0.00
        account['amount'] = new_balance_from
        #print(f"cash in {amount} to {account['id']} ")
        transaction_data = [str(uuid.uuid4()),
                            'PAYMENT',
                            amount,
                            account['id'],
                            old_balance_from,
                            new_balance_from,
                            '',
                            old_balance_to,
                            new_balance_to]
        self.transaction_queue.append(transaction_data)

    def run_cash_out(self):
        account = random.choice(self.accounts)
        amount = my_round(random.uniform(0, account['amount']), 2)
        if amount == 0:
            return
        old_balance_from = account['amount']
        old_balance_to = 0.00
        new_balance_from = my_round(account['amount'] - amount, 2)
        new_balance_to = 0.00
        account['amount'] = new_balance_from
        #print(f"cash out {amount} from {account['id']} ")

        transaction_data = [str(uuid.uuid4()),
                            'CASH_OUT',
                            amount,
                            account['id'],
                            old_balance_from,
                            new_balance_from,
                            '',
                            old_balance_to,
                            new_balance_to]
        self.transaction_queue.append(transaction_data)

    def run_debit(self):
        account = random.choice(self.accounts)
        amount = round(random.uniform(0, account['amount']), 2)
        if amount == 0:
            return

        old_balance_from = account['amount']
        old_balance_to = 0.00
        new_balance_from = my_round(account['amount'] - amount, 2)
        new_balance_to = 0.00
        account['amount'] = new_balance_from
        #print(f"debit {amount} from {account['id']} ")

        transaction_data = [str(uuid.uuid4()),
                            'CASH_OUT',
                            amount,
                            account['id'],
                            old_balance_from,
                            new_balance_from,
                            '',
                            old_balance_to,
                            new_balance_to]

        self.transaction_queue.append(transaction_data)

    def run_write(self):
        header = ["id", "type", "amount", "account_from",
                        "old_balance_from", "new_balance_from",
                        "account_to", "old_balance_to", "new_balance_to"]
        if self.target == 'proton':
            url = f'{proton_ingest_url}/online_payments'
            data = {
                "columns": header,
                "data": self.transaction_queue
            }
            response = requests.post(url, json=data, auth=(timeplus_user, timeplus_password))
            if response.status_code > 299:
                print(f'code : {response.status_code}, text :{response.text} ')
        else:
            try:
                stream = (
                    Stream(env=env)
                    .name("online_payments")
                )
                stream.ingest(header, self.transaction_queue)
            except Exception as e:
                pprint(e)

        self.transaction_queue = []

    def run_write_with_data(self, data):
        header = ["id", "type", "amount",
                        "account_from", "old_balance_from", "new_balance_from",
                        "account_to", "old_balance_to", "new_balance_to"]
        if self.target == 'proton':
            url = f'{proton_ingest_url}/online_payments'
            data = {
                "columns": header,
                "data": data
            }
            response = requests.post(url, json=data, auth=(timeplus_user, timeplus_password))
            if response.status_code > 299:
                print(f'code : {response.status_code}, text :{response.text} ')
        else:
            try:
                stream = (
                    Stream(env=env)
                    .name("online_payments")
                )
                stream.ingest(header, data)
            except Exception as e:
                pprint(e)

    def run_ground_truth(self, id, type_str):
        header = ["id", "is_fraud", "type"]
        data = [[id, True, type_str]]
        if self.target == 'proton':
            url = f'{proton_ingest_url}/online_payments_label'
            data = {
                "columns": header,
                "data": data
            }
            response = requests.post(url, json=data, auth=(timeplus_user, timeplus_password))
            if response.status_code > 299:
                print(f'code : {response.status_code}, text :{response.text} ')
        else:
            try:
                stream = (
                    Stream(env=env)
                    .name("online_payments_label")
                )
                stream.ingest(header, data)
            except Exception as e:
                pprint(e)

    def run_fraud(self):
        #print('run fraud')
        frauds = [ self.run_fraud_type1, self.run_fraud_type2, self.run_fraud_type3]
        fraud_transaction = random.choice(frauds)
        fraud_transaction()

    # transfer all followed by 0.01
    def run_fraud_type1(self):
        account_from = random.choice(self.accounts)
        account_to = random.choice(self.accounts)
        if account_from['amount'] < self.fraud_threshold:
            #print('not enough money for type 1 fraud')
            return

        amount = 0.01
        old_balance_from = account_from['amount']
        old_balance_to = account_to['amount']
        new_balance_from = my_round(account_from['amount'] - amount, 2)
        new_balance_to = my_round(account_to['amount'] + amount, 2)
        account_from['amount'] = new_balance_from
        account_to['amount'] = new_balance_to
        #print(f"transfer {amount} from {account_from['id']} to {account_to['id'] }")
        id = str(uuid.uuid4())
        transaction_data = [id, 'TRANSFER', amount,
                            account_from['id'], old_balance_from, new_balance_from,
                            account_to['id'], old_balance_to, new_balance_to]
        self.run_write_with_data([transaction_data])
        self.run_ground_truth(id, 'type1')

        time.sleep(3)

        amount = account_from['amount']
        old_balance_from = account_from['amount']
        old_balance_to = account_to['amount']
        new_balance_from = 0
        new_balance_to = my_round(account_to['amount'] + amount, 2)
        account_from['amount'] = new_balance_from
        account_to['amount'] = new_balance_to
        print(f"fraud type 1 transfer {amount} from {account_from['id']} to {account_to['id'] }")
        id = str(uuid.uuid4())
        transaction_data = [id, 'TRANSFER', amount,
                            account_from['id'], old_balance_from, new_balance_from,
                            account_to['id'], old_balance_to, new_balance_to]
        self.run_write_with_data([transaction_data])
        self.run_ground_truth(id, 'type1')

    # transfer all money into different accounts
    def run_fraud_type2(self):
        account_from = random.choice(self.accounts)

        if account_from['amount'] < self.fraud_threshold:
            #print('not enough money for type 2 fraud')
            return

        random_account_to = random.sample(self.accounts, 5)

        for account_to in random_account_to:
            account_to = random.choice(self.accounts)
            amount = round(random.uniform(0, account_from['amount']), 2)
            if amount == 0:
                continue
            old_balance_from = account_from['amount']
            old_balance_to = account_to['amount']
            new_balance_from = my_round(account_from['amount'] - amount, 2)
            new_balance_to = my_round(account_to['amount'] + amount, 2)
            account_from['amount'] = new_balance_from
            account_to['amount'] = new_balance_to
            print(f"fraud type 2 transfer {amount} from {account_from['id']} to {account_to['id'] }")
            id = str(uuid.uuid4())
            transaction_data = [id, 'TRANSFER', amount,
                                account_from['id'], old_balance_from, new_balance_from,
                                    account_to['id'], old_balance_to, new_balance_to]
            self.run_write_with_data([transaction_data])
            self.run_ground_truth(id, 'type2')
            time.sleep(1)

    # pay all money to a merchant
    def run_fraud_type3(self):
        account_from = random.choice(self.accounts)

        if account_from['amount'] < self.fraud_threshold:
            #print('not enough money for type 3 fraud')
            return

        account_to = random.choice(self.maccounts)
        amount = account_from['amount']
        old_balance_from = account_from['amount']
        old_balance_to = 0
        new_balance_from = 0
        new_balance_to = 0
        account_from['amount'] = new_balance_from
        account_to['amount'] = new_balance_to
        print(f"fraud type 3 transfer {amount} from {account_from['id']} to {account_to['id'] }")
        id = str(uuid.uuid4())
        transaction_data = [id, 'PAYMENT', amount,
                            account_from['id'], old_balance_from, new_balance_from,
                            account_to['id'], old_balance_to, new_balance_to]
        self.run_write_with_data([transaction_data])
        self.run_ground_truth(id, 'type3')
        time.sleep(1)

    def run(self):
        while True:
            is_fraud = random.randint(0,1000) > ( 1 - self.fraud_rate) * 1000
            if is_fraud:
                self.run_fraud()
            else:
                transaction = random.choices(self.payment_types, weights=self.payment_types_weights)[0]
                #print(f'run a transaction {transaction}')

                if transaction == 'PAYMENT':
                    self.run_payment()

                if transaction == 'TRANSFER':
                    self.run_transfer()

                if transaction == 'CASH_IN':
                    self.run_cash_in()

                if transaction == 'CASH_OUT':
                    self.run_cash_out()

                if transaction == 'DEBIT':
                    self.run_debit()

                if len(self.transaction_queue) >= self.batch:
                    self.run_write()

            time.sleep(self.interval)


@click.command()
@click.option('--target', default='proton', help='use proton or timeplus')
def run(target):
    """entry point."""

    if target == 'proton':
        print('initialize using proton')
        init_proton()
    elif target == 'timeplus':
        # clean_timeplus()
        init_timeplus()
        print('initialize using timeplus')

    sim = PaymentSimulator(number_of_account=100000,
                           number_of_m_account=10000,
                           interval=0.1,
                           batch=10,
                           fraud_rate=0.02,
                           target=target)
    sim.run()


if __name__ == '__main__':
    run()
