CREATE OR REPLACE aggregate FUNCTION forecast_agg(timestamp string, value float64) RETURNS float64 LANGUAGE PYTHON AS 
$$

import pandas as pd
import pickle
from statsmodels.tsa.arima.model import ARIMA

class forecast_agg:
    def __init__(self):
        self.model = None  # ARIMA model will be created dynamically
        self.ts = []  # Store raw time series data
        self.forecast = None
        self.order = (1, 1, 1)  # Default ARIMA order (p, d, q)

    def serialize(self):
        """Serialize only the time series data, since ARIMA models are not picklable."""
        data = {"ts": self.ts, "order": self.order}
        return pickle.dumps(data)

    def deserialize(self, data):
        """Deserialize time series data and recreate the model."""
        data = pickle.loads(data)
        self.ts = data["ts"]
        self.order = data["order"]
        self.model = None  # The model will be refitted in process()

    def merge(self, other):
        pass

    def process(self, timestamp, value):
        """Process new data points and generate forecast."""
        try:
            for t, v in zip(timestamp, value):
                self.ts.append((t, v))

            df = pd.DataFrame(self.ts, columns=["ds", "y"])
            df["ds"] = pd.to_datetime(df["ds"])
            df = df.tail(12)  # Keep only the last 12 months
            df.set_index("ds", inplace=True)

            if len(df) < 5:  # ARIMA needs enough data points to estimate parameters
                self.forecast = None
                return

            # Fit the ARIMA model
            self.model = ARIMA(df["y"], order=self.order)
            fitted_model = self.model.fit()

            # Forecast the next time step
            forecast = fitted_model.forecast(steps=1)
            self.forecast = forecast.iloc[0]

        except Exception as e:
            self.forecast = None

    def finalize(self):
        """Return the final forecasted value."""
        return [self.forecast] if self.forecast is not None else [0.0]

$$;