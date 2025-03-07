
CREATE OR REPLACE FUNCTION pytorch_timeseries_forecaster(values array(float64), seq_length int, prediction_size int) RETURNS array(float64) LANGUAGE PYTHON AS 
$$

import torch
import torch.nn as nn
import torch.optim as optim
import pandas as pd
import numpy as np
import traceback
from sklearn.preprocessing import MinMaxScaler


class LSTMModel(nn.Module):
    def __init__(self, input_size=1, hidden_layer_size=50, output_size=1):
        super().__init__()
        self.hidden_layer_size = hidden_layer_size
        self.lstm = nn.LSTM(input_size, hidden_layer_size, batch_first=True)
        self.linear = nn.Linear(hidden_layer_size, output_size)

    def forward(self, x):
        h0 = torch.zeros(1, x.size(0), self.hidden_layer_size).to(x.device)
        c0 = torch.zeros(1, x.size(0), self.hidden_layer_size).to(x.device)
        lstm_out, _ = self.lstm(x, (h0, c0))
        predictions = self.linear(lstm_out[:, -1, :])
        return predictions

def create_sequences(data, seq_length):
    xs, ys = [], []
    for i in range(len(data) - seq_length):
        x = data[i:i + seq_length]
        y = data[i + seq_length]
        xs.append(x)
        ys.append(y)
    return np.array(xs), np.array(ys)

def pytorch_timeseries_forecaster(values, seq_length, prediction_size):
    results = []
    for (values, seq_length, prediction_size) in zip(values, seq_length, prediction_size):
        try:
            data = np.array(values)
            scaler = MinMaxScaler(feature_range=(-1, 1))
            data_normalized = scaler.fit_transform(data.reshape(-1, 1)).flatten()

            X, y = create_sequences(data_normalized, seq_length)

            X = torch.tensor(X, dtype=torch.float32).unsqueeze(-1)  # Add feature dimension
            y = torch.tensor(y, dtype=torch.float32).unsqueeze(-1)  # Add feature dimension

            model = LSTMModel()
            loss_function = nn.MSELoss()
            optimizer = optim.Adam(model.parameters(), lr=0.001)

            # Train the model
            epochs = 100
            for epoch in range(epochs):
                model.train()
                optimizer.zero_grad()
                y_pred = model(X)
                loss = loss_function(y_pred, y)
                loss.backward()
                optimizer.step()

            model.eval()
            with torch.no_grad():
                last_sequence = data_normalized[-seq_length:]
                test_seq = torch.tensor(last_sequence, dtype=torch.float32).unsqueeze(0).unsqueeze(-1)  # Shape: [1, seq_length, 1]
                predictions = []
                for _ in range(prediction_size): 
                    y_pred = model(test_seq)
                    predictions.append(y_pred.item()) 
                    y_pred = y_pred.unsqueeze(-1)  # Shape: [1, 1, 1]
                    test_seq = torch.cat((test_seq[:, 1:, :], y_pred), dim=1)

            predictions = scaler.inverse_transform(np.array(predictions).reshape(-1, 1)).flatten()
            results.append(predictions.tolist())
        except Exception as e:
            trace = traceback.format_exc()
            results.append([])

    return results

$$;