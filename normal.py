import pandas as pd

normal = pd.read_csv("normal.csv")
normal.rename(columns={
    "temperature_celsius": "temperature",
    "precip_mm": "rainfall",
    "wind_kph": "wind_speed",
    "pressure_mb": "pressure"
}, inplace=True)

normal.columns = normal.columns.str.strip()

# Step 3: Remove Duplicates
normal.drop_duplicates(inplace=True)

# Step 4: Remove Impossible Values
normal = normal[
    (normal["temperature"] >= -20) &
    (normal["temperature"] <= 60) &
    (normal["humidity"] >= 0) &
    (normal["humidity"] <= 100) &
    (normal["rainfall"] >= 0) &
    (normal["wind_speed"] >= 0) &
    (normal["pressure"] >= 850) &
    (normal["pressure"] <= 1100)
]
# Step 5: Fill Missing Values
normal["temperature"] = normal["temperature"].fillna(normal["temperature"].median())
normal["humidity"] = normal["humidity"].fillna(normal["humidity"].median())
normal["rainfall"] = normal["rainfall"].fillna(0)
normal["wind_speed"] = normal["wind_speed"].fillna(normal["wind_speed"].median())
normal["pressure"] = normal["pressure"].fillna(normal["pressure"].median())

# Step 6: Select Normal Weather
normal = normal[
    (normal["temperature"] >= 20) &
    (normal["temperature"] <= 35) &
    (normal["humidity"] >= 30) &
    (normal["humidity"] <= 70) &
    (normal["rainfall"] <= 10)
].copy()

normal = normal.sample(n=3000, random_state=42)

# Step 7: Add Label
normal["disaster_type"] = "Normal"

# Step 8: Keep Required Columns
normal = normal[
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
normal.to_csv("cleaned_normal.csv", index=False)

print("Normal records:", len(normal))
print(normal.head())
print(normal.info())