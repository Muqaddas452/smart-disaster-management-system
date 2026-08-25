import pandas as pd
import joblib

# Load Saved Model
model = joblib.load("weather_disaster_model.pkl")
label_encoder = joblib.load("label_encoder.pkl")

# Load New Data
manual = pd.read_csv("manual_test.csv")

# Keep the same feature order used during training
X_new = manual[
    [
        "temperature",
        "humidity",
        "rainfall",
        "wind_speed",
        "pressure"
    ]
]

# Predict
prediction = model.predict(X_new)

# Convert numeric labels back to text
prediction = label_encoder.inverse_transform(prediction)

manual["Prediction"] = prediction

print(manual)

# Save predictions
manual.to_csv("prediction_results.csv", index=False)

print("\nPredictions saved to prediction_results.csv")