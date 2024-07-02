import os
import openai
from retry import retry
from ..utils.logging import getLogger

logger = getLogger()


@retry(tries=3, delay=2)
def embedding(input):
    logger.info(f'input is : {input}')
    response = openai.Embedding.create(
        input=input,
        model="text-embedding-ada-002"
    )
    return response['data'][0]['embedding']


class Embbedder:
    def __init__(self):
        openai.organization = "org-2lL52vp8vsIoEQ5VxEZzb1UC"
        openai.api_key = os.getenv("OPENAI_API_KEY")

    def embedding(self, input):
        return embedding(input)
