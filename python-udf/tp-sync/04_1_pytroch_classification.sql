CREATE OR REPLACE AGGREGATE FUNCTION train_pytorch_classifier(features array(float64), label string, name string) RETURNS string LANGUAGE PYTHON AS 
$$

import torch
import torch.nn as nn
import torch.optim as optim
import pandas as pd
import numpy as np
from sklearn.preprocessing import LabelEncoder
import pickle


class SimpleNN(nn.Module):
    def __init__(self, input_size, hidden_size, output_size):
        super(SimpleNN, self).__init__()
        self.fc1 = nn.Linear(input_size, hidden_size)
        self.relu = nn.ReLU()
        self.fc2 = nn.Linear(hidden_size, output_size)
    
    def forward(self, x):
        out = self.fc1(x)
        out = self.relu(out)
        out = self.fc2(out)
        return out


class train_pytorch_classifier:
    def __init__(self):
        self.model = None
        self.label_encoder = None

    def serialize(self):
        data = {
            "model_state_dict": self.model.state_dict(),
            "label_encoder": self.label_encoder
        }
        return pickle.dumps(data)

    def deserialize(self, data):
        data = pickle.loads(data)
        self.model.load_state_dict(data["model_state_dict"])
        self.label_encoder = data["label_encoder"]

    def merge(self, other):
        pass

    def process(self, features, labels, names):
        try:
            # Convert features and labels to numpy arrays
            X = np.array(features, dtype=np.float32)
            y = np.array(labels)
            
            # Encode labels (convert strings to integers)
            self.label_encoder = LabelEncoder()
            y_encoded = self.label_encoder.fit_transform(y)
            
            # Convert to PyTorch tensors
            X_tensor = torch.tensor(X, dtype=torch.float32)
            y_tensor = torch.tensor(y_encoded, dtype=torch.long)
            
            # Define the neural network
            input_size = X.shape[1]
            hidden_size = 10
            output_size = len(self.label_encoder.classes_)
            self.model = SimpleNN(input_size, hidden_size, output_size)
            
            # Define loss and optimizer
            criterion = nn.CrossEntropyLoss()
            optimizer = optim.Adam(self.model.parameters(), lr=0.01)
            
            # Train the model
            num_epochs = 100
            for epoch in range(num_epochs):
                # Forward pass
                outputs = self.model(X_tensor)
                loss = criterion(outputs, y_tensor)
                
                # Backward pass and optimization
                optimizer.zero_grad()
                loss.backward()
                optimizer.step()
            
            # Save the model and label encoder
            with open(f'{names[0]}.pkl', 'wb') as f:
                pickle.dump({
                    "model_state_dict": self.model.state_dict(),
                    "label_encoder": self.label_encoder
                }, f)
            
            self.model = str(self.model)

        except Exception as e:
            self.model = str(e) 

    def finalize(self):
        return [self.model]

$$;

CREATE OR REPLACE FUNCTION predict_pytorch_classifier(features array(float64), name string) RETURNS string LANGUAGE PYTHON AS 
$$

import traceback
import torch
import numpy as np
import pickle


def predict_pytorch_classifier(features, name):
    results = []
    for (feature, name) in zip(features, name):
        try:
            with open(f'{name}.pkl', 'rb') as f:
                data = pickle.load(f)
                model_state_dict = data["model_state_dict"]
                label_encoder = data["label_encoder"]
            
            # Define the neural network
            input_size = len(feature)
            hidden_size = 10
            output_size = len(label_encoder.classes_)
            model = SimpleNN(input_size, hidden_size, output_size)
            model.load_state_dict(model_state_dict)
            model.eval()  # Set the model to evaluation mode
            
            # Convert input features to a tensor
            X_tensor = torch.tensor([feature], dtype=torch.float32)
            
            # Make predictions
            with torch.no_grad():
                outputs = model(X_tensor)
                _, predicted = torch.max(outputs, 1)
                predicted_label = label_encoder.inverse_transform(predicted.numpy())
                results.append(str(predicted_label[0]))
        
        except Exception as e:
            trace = traceback.format_exc()
            results.append(trace)

    return results

$$;