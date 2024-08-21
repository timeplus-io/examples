from typing import List
from fastapi import FastAPI
from pydantic import BaseModel

from .model.chat import Detector


app = FastAPI()
detector = Detector()

class EventsItem(BaseModel):
    events: List[List[List[float]]]


@app.get("/")
def info():
    return {"info": "timeplus pattern detectserver"}


@app.post("/detect")
def detect(item: EventsItem):
    results = []
    for e in item.events:
        patterns = detector.detect(e)
        print(f"find patters {patterns}")
        results.append(patterns)

    return {"result": results}
