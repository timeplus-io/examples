
CREATE OR REPLACE FUNCTION sentiment_analyzer(input string) RETURNS string LANGUAGE PYTHON AS 
$$
import json
import traceback
from transformers import pipeline

pipe = pipeline("text-classification", 
                model="distilbert/distilbert-base-uncased-finetuned-sst-2-english", 
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



CREATE OR REPLACE FUNCTION sentiment_analyzer(input string) RETURNS string LANGUAGE PYTHON AS 
$$
import json
import traceback
import torch
import torch.nn.functional as F
from transformers import AutoTokenizer, AutoModelForSequenceClassification

# Check if GPU is available and set device accordingly
device = "cuda" if torch.cuda.is_available() else "cpu"

# Force gradient calculation off for inference
torch.set_grad_enabled(False)

# Load model components separately
model_name = "distilbert-base-uncased-finetuned-sst-2-english"
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForSequenceClassification.from_pretrained(
    model_name, 
    torchscript=True,
    return_dict=False
)
# Move model to appropriate device
model = model.to(device)
model.eval()  # Set to evaluation mode

def sentiment_analyzer(input):
    results = []
    
    # Check if input is a string or list-like
    if isinstance(input, str):
        inputs = [input]
    else:
        inputs = input
        
    for input_string in inputs:
        try:
            input_string = str(input_string)[:1024]
            
            # Manual processing instead of using pipeline
            encoded_input = tokenizer(input_string, 
                                     truncation=True, 
                                     max_length=512, 
                                     return_tensors='pt')
            
            # Move input tensors to the same device as model
            encoded_input = {k: v.to(device) for k, v in encoded_input.items()}
            
            with torch.no_grad():
                output = model(**encoded_input)
                
            # Get prediction and convert to probabilities
            logits = output[0][0].detach()
            
            # Apply softmax to convert logits to probabilities
            probs = F.softmax(logits, dim=0)
            
            # Move results back to CPU for numpy conversion if needed
            if device != "cpu":
                probs = probs.cpu()
                
            probs = probs.numpy()
            
            # Create result with probabilities
            result = {
                "label": model.config.id2label[probs.argmax().item()],
                "score": float(probs.max().item()),  # Max probability
                "details": {
                    model.config.id2label[i]: float(prob) 
                    for i, prob in enumerate(probs)
                }
            }
            
            results.append(json.dumps(result))
            
        except Exception as e:
            trace = traceback.format_exc()
            results.append(f"Error: {str(e)}\n{trace}")

    # Return a single string if input was single, otherwise return the list
    if isinstance(input, str):
        return results[0] if results else ""
    return results

$$;