import pandas as pd

# Step 1: Load Dataset
heavy_rain = pd.read_csv("Rainfall dataset.csv")

# Step 2: Remove Duplicates
heavy_rain.drop_duplicates(inplace=True)

# Step 3: Create Common Features
# Average temperature
heavy_rain["temperature"] = (heavy_rain["min_temperature"] + heavy_rain["max_temperature"]) / 2

# Average humidity
heavy_rain["humidity"] = (heavy_rain["Humidity9am"] + heavy_rain["Humidity3pm"]) / 2

# Average wind speed
heavy_rain["wind_speed"] = (heavy_rain["WindSpeed9am"] + heavy_rain["WindSpeed3pm"]) / 2

# Average pressure
heavy_rain["pressure"] = (heavy_rain["Pressure9am"] + heavy_rain["Pressure3pm"]) / 2

# Step 4: Remove Impossible Values
heavy_rain = heavy_rain[
    (heavy_rain["temperature"] >= -20) &
    (heavy_rain["temperature"] <= 60) &
    (heavy_rain["humidity"] >= 0) &
    (heavy_rain["humidity"] <= 100) &
    (heavy_rain["rainfall"] >= 0) &
    (heavy_rain["wind_speed"] >= 0) &
    (heavy_rain["pressure"] >= 850) &
    (heavy_rain["pressure"] <= 1100)
]
# Step 5: Fill Missing Values
# ==========================

heavy_rain["temperature"] = heavy_rain["temperature"].fillna(heavy_rain["temperature"].median())
heavy_rain["humidity"] = heavy_rain["humidity"].fillna(heavy_rain["humidity"].median())
heavy_rain["rainfall"] = heavy_rain["rainfall"].fillna(0)
heavy_rain["wind_speed"] = heavy_rain["wind_speed"].fillna(heavy_rain["wind_speed"].median())
heavy_rain["pressure"] = heavy_rain["pressure"].fillna(heavy_rain["pressure"].median())

# Step 6: Filter Heavy Rain

heavy_rain = heavy_rain[
    (heavy_rain["rainfall"] >= 20)
].copy()

# Step 7: Add Label
heavy_rain["disaster_type"] = "HeavyRain"

# Step 8: Keep Required Columns
heavy_rain = heavy_rain[
    [
        "temperature",
        "humidity",
        "rainfall",
        "wind_speed",
        "pressure",
        "disaster_type"
    ]
]

# Step 9: Save Dataset
heavy_rain.to_csv("cleaned_rainfall.csv", index=False)

# Step 10: Verify
print("Heavy Rain records:", len(heavy_rain))
print(heavy_rain.head())
print(heavy_rain.info())