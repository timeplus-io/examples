CREATE OR REPLACE aggregate FUNCTION train_sklearn_classifier(features array(float64), label string, name string) RETURNS string LANGUAGE PYTHON AS 
$$

import numpy as np
import pandas as pd
import joblib
from sklearn.preprocessing import LabelEncoder
from sklearn.linear_model import LogisticRegression

class train_sklearn_classifier:
    def __init__(self):
        self.model = ''

    def serialize(self):
        data = {}
        data["model"] = self.model
        return pickle.dumps(data)

    def deserialize(self, data):
        data = pickle.loads(data)
        self.model = data["model"]

    def merge(self, other):
        pass

    def process(self, features, labels, names):
        try:
            data = []
            for feature, label in zip(features, labels):
                row = feature + [label]  # Create a new list with label appended
                data.append(row)
            
            feature_names = [f'f{n}' for n in range(len(features[0]))]
            df = pd.DataFrame(data, columns=feature_names + ['label'])

            X = df[feature_names].values  # Features
            y = df['label'].values  # Labels
            label_encoder = LabelEncoder()
            y_encoded = label_encoder.fit_transform(y)
            
            classifier = LogisticRegression(max_iter=200)
            classifier.fit(X, y)
            joblib.dump(classifier, f'{names[0]}.pkl')
            self.model = str(classifier) 

        except Exception as e:
            self.model = str(e) 

    def finalize(self):
        return [self.model]

$$;

CREATE OR REPLACE FUNCTION predict_sklearn_classifier(features array(float64), name string) RETURNS string LANGUAGE PYTHON AS 
$$
import traceback 
import joblib
import numpy as np

def predict_sklearn_classifier(features, name):
    results = []
    for (features, name) in zip(features, name):
        try:
            loaded_classifier = joblib.load(f'{name}.pkl')
            new_data = np.array([features]) 
            new_prediction = loaded_classifier.predict(new_data)
            results = [ str(v) for v in new_prediction]
        except Exception as e:
            trace = traceback.format_exc()
            results.append(trace)

    return results

$$;