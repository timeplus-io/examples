
CREATE OR REPLACE FUNCTION sentiment_analyzer(input string) RETURNS string LANGUAGE PYTHON AS 
$$
import json
from transformers import pipeline

pipe = pipeline("text-classification", model="cardiffnlp/twitter-roberta-base-sentiment-latest")

def sentiment_analyzer(input):
    results = []
    for input_string in input:
        try:
            result = pipe(input_string)
            results.append(json.dumps(result[0]))
        except Exception as e:
            trace = traceback.format_exc()
            results.append(trace)

    return results

$$;