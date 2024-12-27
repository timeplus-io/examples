import os
from typing import List
from fastapi import FastAPI
from pydantic import BaseModel

from .user import BlueskyUserFetcher
from .post import BlueskyPostFetcher


app = FastAPI()
user_fethcer = BlueskyUserFetcher()
post_fetcher = BlueskyPostFetcher()
username = os.getenv("BLUESKY_USER")
passowrd = os.getenv("BLUESKY_PASSWORD")


class UserFetchItem(BaseModel):
    did: List[str]


class PostFetchItem(BaseModel):
    cid: List[str]
    uri: List[str]


@app.get("/")
def info():
    return {"info": "timeplus bluesky analysis server"}


@app.post("/user")
def user(item: UserFetchItem):
    results = []
    success = user_fethcer.authenticate(username, passowrd)

    for did in item.did:
        user = user_fethcer.get_user_info(did)
        if success:
            results.append(user.to_json())
        else:
            results.append("failed to authenticate")

    return {"result": results}

@app.post("/post")
def post(item: PostFetchItem):
    results = []
    success = post_fetcher.authenticate(username, passowrd)

    for (cid, uri) in zip(item.cid, item.uri):
        content = post_fetcher.get_post_by_cid(cid, uri)
        if success:
            results.append(content.to_json())
        else:
            results.append("failed to authenticate")

    return {"result": results}
