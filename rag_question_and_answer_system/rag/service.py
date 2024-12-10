import os
from openai import OpenAI

from typing import List
from fastapi import FastAPI
from pydantic import BaseModel

client = OpenAI(
                base_url=os.getenv("LLM_BASE_URL"),
                # required but ignored
                api_key="ollama"
            )
app = FastAPI()

class PredictItem(BaseModel):
    input: List[str]

def _embedding(input):
    response = client.embeddings.create(
        input=input,
        model="mxbai-embed-large:latest"
    )
    return response.data[0].embedding

def _complete(messages):
    response = client.chat.completions.create(
        model="llama3.2:1b", 
        messages=[
                {"role": "user", "content": messages},
            ],
        temperature=0
    )
    return response.choices[0].message.content

@app.get("/")
def info():
    return {"info": "timeplus chat bot server"}

@app.post("/embedding")
def embedding(item: PredictItem):
    results = []
    for input in item.input:
        results.append(_embedding(input))

    return {"result": results}

@app.post("/chat")
def chat(item: PredictItem):
    results = []
    for input in item.input:
        results.append(_complete(input))

    return {"result": results}
