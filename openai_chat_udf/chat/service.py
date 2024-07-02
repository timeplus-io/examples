from typing import List
from fastapi import FastAPI
from pydantic import BaseModel

from .utils.logging import getLogger
from .model.chat import Bot
from .model.embedding import Embbedder


app = FastAPI()
logger = getLogger()
bot = Bot()
embedder = Embbedder()


class ChatItem(BaseModel):
    input: List[str]
    temperature: List[float]


class ContextChatItem(BaseModel):
    input: List[str]
    temperature: List[float]
    user: List[str]


class PredictItem(BaseModel):
    input: List[str]


@app.get("/")
def info():
    return {"info": "timeplus chat bot server"}


@app.post("/chat")
def chat(item: ChatItem):
    results = []
    for (input, t) in zip(item.input, item.temperature):
        results.append(bot.chat(input, temp=t))

    return {"result": results}


@app.post("/embedding")
def embedding(item: PredictItem):
    results = []
    for input in item.input:
        results.append(embedder.embedding(input))

    return {"result": results}
