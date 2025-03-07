
CREATE OR REPLACE FUNCTION transformer_sentiment_analyzer(input string) RETURNS string LANGUAGE PYTHON AS 
$$
from transformers import pipeline


def transformer_sentiment_analyzer(input):
    model_dir = "/timeplus/tmp/models"
    model_name = "distilbert-base-uncased-finetuned-sst-2-english"

    results = []
    for input_string in input:
        try:
            sentiment_analyzer = pipeline(
                "sentiment-analysis",
                model= model_name,  
                tokenizer=model_name, 
                model_kwargs={"cache_dir": model_dir}
            )

            result = sentiment_analyzer(input_string)
            results.append(str(result))
        except Exception as e:
            trace = traceback.format_exc()
            results.append(trace)

    return results

$$;