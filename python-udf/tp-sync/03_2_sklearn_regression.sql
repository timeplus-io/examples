
CREATE OR REPLACE AGGREGATE FUNCTION train_sklearn_regressor(features array(float64), target float64, name string) RETURNS string LANGUAGE PYTHON AS 
$$

import numpy as np
import pandas as pd
import joblib
from sklearn.linear_model import LinearRegression  # Changed to LinearRegression


class train_sklearn_regressor:
    def __init__(self):
        self.model = ''

    def serialize(self):
        data = {}
        data["model"] = self.model
        return joblib.dumps(data)  # Use joblib for serialization

    def deserialize(self, data):
        data = joblib.loads(data)
        self.model = data["model"]

    def merge(self, other):
        pass

    def process(self, features, targets, names):
        try:
            data = []
            for feature, target in zip(features, targets):
                row = feature + [target]  # Create a new list with target appended
                data.append(row)
            
            feature_names = [f'f{n}' for n in range(len(features[0]))]
            df = pd.DataFrame(data, columns=feature_names + ['target'])  # Use 'target' instead of 'label'

            X = df[feature_names].values  # Features
            y = df['target'].values  # Targets (continuous values)
            
            regressor = LinearRegression()  # Use LinearRegression for regression
            regressor.fit(X, y)
            joblib.dump(regressor, f'{names[0]}.pkl')  # Save the regression model
            self.model = str(regressor) 

        except Exception as e:
            self.model = str(e) 

    def finalize(self):
        return [self.model]

$$;

CREATE OR REPLACE FUNCTION predict_sklearn_regressor(features array(float64), name string) RETURNS float64 LANGUAGE PYTHON AS 
$$

import traceback 
import joblib
import numpy as np

def predict_sklearn_regressor(features, name):
    results = []
    for (feature, model_name) in zip(features, name):
        try:
            loaded_regressor = joblib.load(f'{model_name}.pkl')  # Load the regression model
            new_data = np.array([feature])  # Convert features to NumPy array
            new_prediction = loaded_regressor.predict(new_data)  # Predict continuous value
            results.append(float(new_prediction[0]))  # Append the predicted value as float
        except Exception as e:
            trace = traceback.format_exc()
            results.append(trace)

    return results

$$;