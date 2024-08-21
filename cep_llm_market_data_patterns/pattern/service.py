from typing import List
from fastapi import FastAPI
from pydantic import BaseModel


app = FastAPI()

class EventsItem(BaseModel):
    events: List[List[List[float]]]


@app.get("/")
def info():
    return {"info": "timeplus pattern detectserver"}


@app.post("/detect")
def detect(item: EventsItem):
    results = []
    for e in item.events:
        print(f"got an event {e}")
        results.append(["pa_1","pa_2"])

    return {"result": results}
