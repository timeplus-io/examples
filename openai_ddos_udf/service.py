from typing import List
from fastapi import FastAPI
from pydantic import BaseModel

from is_ddos import Detector


app = FastAPI()
bot = Detector()


class PredictItem(BaseModel):
    bwd_packet_length_min: List[float]
    bwd_packet_length_std: List[float]
    avg_packet_size: List[float]
    flow_duration: List[float]
    flow_iat_std: List[float]


@app.get("/")
def info():
    return {"info": "DDoS detection server"}


@app.post("/is_ddos")

def is_ddos(item: PredictItem):
    results = []
    for (bwd_packet_length_min, bwd_packet_length_std, avg_packet_size, flow_duration, flow_iat_std) in zip(item.bwd_packet_length_min, item.bwd_packet_length_std, item.avg_packet_size, item.flow_duration, item.flow_iat_std):
        results.append(bot.is_ddos(bwd_packet_length_min, bwd_packet_length_std, avg_packet_size, flow_duration, flow_iat_std))

    return {"result": results}