from typing import List
from fastapi import FastAPI
from pydantic import BaseModel

from .model.chat import Detector
from .utils.logging import getLogger


app = FastAPI()
logger = getLogger()
detector = Detector()

class EventsItem(BaseModel):
    events: List[List[List[float]]]


@app.get("/")
def info():
    return {"info": "timeplus pattern detect server"}


@app.post("/detect")
def detect(item: EventsItem):
    results = []
    for e in item.events:
        patterns = detector.detect(e)
        results.append(patterns)

    logger.info(f"detected patterns ${results}")
    return {"result": results}
