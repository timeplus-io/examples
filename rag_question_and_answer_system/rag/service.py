import os
import openai

from typing import List
from fastapi import FastAPI
from pydantic import BaseModel

openai.api_key = os.getenv("OPENAI_API_KEY")
app = FastAPI()

class PredictItem(BaseModel):
    input: List[str]

def _embedding(input):
    response = openai.Embedding.create(
        input=input,
        model="text-embedding-ada-002"
    )
    return response['data'][0]['embedding']

@app.get("/")
def info():
    return {"info": "timeplus chat bot server"}

@app.post("/embedding")
def embedding(item: PredictItem):
    results = []
    for input in item.input:
        results.append(_embedding(input))

    return {"result": results}
