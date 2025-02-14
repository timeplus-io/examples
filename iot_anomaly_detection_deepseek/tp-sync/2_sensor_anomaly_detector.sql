CREATE OR REPLACE aggregate FUNCTION anomaly_detector(ts datetime, value float64) RETURNS string LANGUAGE PYTHON AS 
$$
import re
from string import Template
from openai import OpenAI
client = OpenAI(api_key="ollama", base_url="http://host.docker.internal:11434/v1")

def extract_code_blocks_with_type(markdown_text):
    pattern = r"```(\w+)?\n(.*?)```"
    matches = re.findall(pattern, markdown_text, re.DOTALL)

    return [(code_type if code_type else "", code_content.strip()) for code_type, code_content in matches]

class anomaly_detector:

    def __init__(self):
        self.prompts = None
        self.data_template = Template('Timestamp: $ts, Value: $value')
        self.prompt_template = Template('''You are an AI assistant analyzing IoT sensor data for anomalies.  
Given the following temperature readings from a factory sensor, identify if there are significant data anomalies and explain why.  

Data:  
$datapoints 

Analyze:  
1. Is there an anomaly?  
2. If yes, explain why it is unusual.  
3. List all the anomalous data points.  

return the result in JSON, here is an example

```json
{
    "is_anomaly" : True,
    "reason" : "why it is anomaly",
    "anomal_datapoints": ["Timestamp: 2025-01-01 18:10:13, Value: 108"],
}
```''')
        self.datapoints = []

    def serialize(self):
        pass

    def deserialize(self, data):
        pass

    def merge(self, other):
        pass

    def process(self, ts, value):
        try:
            for (ts, value) in zip(ts, value):
                self.datapoints.append(self.data_template.substitute(ts=ts, value=value))

            self.prompts = self.prompt_template.substitute(datapoints='\n'.join(self.datapoints))

        except Exception as e:
            self.prompts = (str(e))

    def finalize(self):
        messages = [{"role": "user", "content":self.prompts}]
        try:
            response = client.chat.completions.create(
                model="deepseek-r1:latest",
                messages=messages,
                temperature=0.0
            )
            result = extract_code_blocks_with_type(response.choices[0].message.content)
            return [str(result[0][1])]
        except Exception as e:
            return [str(e)]

$$;