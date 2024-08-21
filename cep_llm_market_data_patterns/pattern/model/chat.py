import os
import openai
import json
from ..utils.logging import getLogger
from retry import retry

logger = getLogger()

prompt = '''
## Context
Candlestick charts are a type of financial chart used to represent the price movements of a security, derivative, or currency over time. Each "candlestick" typically represents one day of trading, but it can be used for different time frames (e.g., minute, hour, day, week). A candlestick provides four key data points for that time period:

Open: The price at the beginning of the time period.
High: The highest price during the time period.
Low: The lowest price during the time period.
Close: The price at the end of the time period.

## Task
Given a sequence of market data, identify if the sequence contains following pattern

Assuming two consecutive candle event e1 and e0, a Bullish Engulfing can be defined as 
- e1.close < e1.open 
- e0.close > e0.open 
- e0.close > e1.open
- e0.open < e1.close 

Assuming two consecutive candle event e1 and e0, a Bearish Engulfing can be defined as 
- e1.close > e1.open 
- e0.close < e0.open 
- e0.close < e1.open
- e0.open > e1.close 

Assuming one candle event e0 , a Doji can be defined as
- abs(e0.close - e0.open) <= 0.2 * (e0.high - e0.low)

Assuming three consecutive candle event e2, e1 and e0, a Morning Star can be defined as 
- e2.close < e2.open 
- abs(e1.close - e1.open) <= 0.2 * (e2.high - e2.low)
- e0.close > e0.open
- e0.close > e2.open
- e0.close  > e2.close

## Target sequence of market data 
__events__

## Output format
Output the results as a JSON object with a key 'patterns' and a list of detected patterns as the value.
A sample output is : {"patterns":["Bullish Engulfing","Morning Star"]}
If the sequence contains a Bullish Engulfing pattern, the response should include "Bullish Engulfing".
If the sequence contains a Bearish Engulfing pattern, the response should include "Bearish Engulfing".
If the sequence contains a Doji pattern, the response should include "Doji".
If the sequence contains a Morning Star pattern, the response should include "Morning Star".
If the sequence does not contain any above pattern, the response pattern should include "None".
'''


@retry(tries=3, delay=2)
def chat(input, temp):
    logger.info(f'input is {input} , temperature is {temp}')
    response = openai.ChatCompletion.create(
        model="gpt-4o",
        messages=[{"role": "user", "content": input}],
        temperature=temp
    )
    logger.info(f'output is {response}')
    return response['choices'][0]['message']['content']


class Detector:
    def __init__(self):
        openai.organization = "org-2lL52vp8vsIoEQ5VxEZzb1UC"
        openai.api_key = os.getenv("OPENAI_API_KEY")

    def detect(self, events):
        events_str = ""
        for e in events:
            event = {}
            event["open"] = e[0]
            event["high"] = e[1]
            event["low"] = e[2]
            event["close"] = e[3]
            events_str = json.dumps(event) + "\n" + events_str
        intput = prompt.replace("__events__", events_str)
        result = chat(intput, temp=0)

        patterns = result.split("json")[-1].strip("```")
        patterns_obj = json.loads(patterns)
        return patterns_obj["patterns"]