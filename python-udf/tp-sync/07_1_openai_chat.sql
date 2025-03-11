CREATE OR REPLACE FUNCTION chat(value string) RETURNS string LANGUAGE PYTHON AS 
$$

import os        
from openai import OpenAI

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

def chat(value):
    res = []

    for v in value:
        try:
            chat_completion = client.chat.completions.create(
                messages=[{
                    "role": "user",
                    "content": v
                }],
                model="gpt-3.5-turbo")
            res.append(chat_completion.choices[0].message.content)
        except Exception as e:
            res.append(str(e))
    return res

$$