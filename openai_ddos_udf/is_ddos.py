import os
import openai
from retry import retry
import pandas as pd
import re


@retry(tries=3, delay=2)
def is_ddos(bwd_packet_length_min, bwd_packet_length_std, avg_packet_size, flow_duration, flow_iat_std):

    # read training data and select samples/features
    friday = pd.read_csv('Friday-WorkingHours-Afternoon-DDos.pcap_ISCX.csv')
    friday.columns = [column.strip() for column in friday.columns]
    train = friday[['Bwd Packet Length Min', 'Bwd Packet Length Std', 'Average Packet Size', 'Flow Duration', 'Flow IAT Std', 'Label']]
    train = train.sample(10)
    test = pd.DataFrame([[bwd_packet_length_min, bwd_packet_length_std, avg_packet_size, flow_duration, flow_iat_std]])

    # helper function to format data into string format useable as a prompt
    def promptify(df):
        column_names = ['Bwd Packet Length Min', 'Bwd Packet Length Std', 'Average Packet Size', 'Flow Duration', 'Time Between Packets Std', 'Label']
        formatted_rows = []
        for index, row in df.iterrows():
            formatted_row = ' | '.join([f'{column_names[i]}: {row.iloc[i]}' for i in range(len(row))])
            formatted_rows.append(formatted_row)
        
        interleaved_rows = []
        while len(formatted_rows) > 1:
            interleaved_rows.append(formatted_rows.pop(0))
            interleaved_rows.append(formatted_rows.pop(-1))
        if len(formatted_rows) == 1:
            interleaved_rows.append(formatted_rows[0])

        return '\n'.join(interleaved_rows)
    
    # assemble the prompt and call OpenAI API to get completion output
    system_prompt = '''You will be provided with a sample of network traffic data that is split between training data and a single testing data (separated by '###'). Each row of data is separated by a newline, and each row has features that are separated by a pipe symbol ('|'). Using information from the training data, predict the best label (BENIGN or DDoS) for the testing data. First explain your reasoning for the selected label. Then indicate the predicted label with '@@@' on each side.'''
    user_prompt = promptify(train) + '\n###\n' + promptify(test)

    completion = openai.chat.completions.create(
        model='gpt-3.5-turbo',
        messages=[
            {'role': 'system', 'content': system_prompt},
            {'role': 'user', 'content': user_prompt}
        ]
    )

    output = completion.choices[0].message.content
    print(output)

    # extract and return the predicted label from the completion output
    label = re.search(r'(?<=\@{3}).+(?=\@{3})', output).group().strip().lower()
    return label == 'ddos'


class Detector:
    def __init__(self):
        openai.api_key = os.getenv("OPENAI_API_KEY")

    def is_ddos(self, bwd_packet_length_min, bwd_packet_length_std, avg_packet_size, flow_duration, flow_iat_std):
        return is_ddos(bwd_packet_length_min, bwd_packet_length_std, avg_packet_size, flow_duration, flow_iat_std)
    

if __name__ == '__main__':
    detector = Detector()
    print(detector.is_ddos(6, 0, 7, 7000000, 3500000))