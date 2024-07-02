import os
import openai
import json
from ..utils.logging import getLogger
from retry import retry

logger = getLogger()


@retry(tries=3, delay=2)
def chat(input, temp):
    logger.info(f'input is {input} , temperature is {temp}')
    response = openai.ChatCompletion.create(
        model="gpt-3.5-turbo",
        messages=[{"role": "user", "content": input}],
        temperature=temp
    )
    logger.info(f'output is {response}')
    return response['choices'][0]['message']['content']


class Bot:
    def __init__(self):
        openai.organization = "org-2lL52vp8vsIoEQ5VxEZzb1UC"
        openai.api_key = os.getenv("OPENAI_API_KEY")

    def chat(self, input, temp):
        return chat(input, temp)