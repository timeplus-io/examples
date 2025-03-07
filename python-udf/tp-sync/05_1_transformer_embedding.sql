
CREATE OR REPLACE FUNCTION transformer_embedding(input string, model string) RETURNS string LANGUAGE PYTHON AS 
$$
import torch
import traceback

from transformers import AutoTokenizer, AutoModel


def transformer_embedding(input, model):
    local_dir = "/timeplus/tmp/models"

    results = []
    for (input_string, model) in zip(input, model):
        try:
            model_name = model  # bert-base-uncased, roberta-base, distilbert-base-uncased
            tokenizer = AutoTokenizer.from_pretrained(model_name, cache_dir=local_dir)
            model = AutoModel.from_pretrained(model_name, cache_dir=local_dir)

            inputs = tokenizer(input_string, return_tensors="pt", padding=True, truncation=True)
            # Generate embeddings
            with torch.no_grad(): 
                outputs = model(**inputs)
            embeddings = outputs.last_hidden_state
            pooled_embedding = torch.mean(embeddings, dim=1)
            pooled_embedding_list = pooled_embedding.squeeze().tolist()
            results.append(str(pooled_embedding_list))
        except Exception as e:
            trace = traceback.format_exc()
            results.append(trace)

    return results

$$;