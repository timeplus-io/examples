
CREATE OR REPLACE FUNCTION sentiment_analyzer(input string) RETURNS string LANGUAGE PYTHON AS 
$$
import json
from transformers import pipeline

pipe = pipeline("text-classification", 
                model="distilbert-base-uncased-finetuned-sst-2-english", 
                device="cpu",
                trust_remote_code=False)

def sentiment_analyzer(input):
    results = []
    for input_string in input:
        try:
            input_string = input_string[:1024]
            result = pipe(input_string, truncation=True, max_length=512)
            results.append(json.dumps(result[0]))
        except Exception as e:
            trace = traceback.format_exc()
            results.append(trace)

    return results

$$;