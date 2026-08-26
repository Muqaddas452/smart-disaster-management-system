import pandas as pd

storm = pd.read_csv("Storm.csv")

# Step 2: Rename Columns
storm.rename(columns={
    "temperature_celsius": "temperature",
    "wind_kph": "wind_speed",
    "pressure_mb": "pressure",
    "precip_mm": "rainfall"
}, inplace=True)

storm.columns = storm.columns.str.strip()

# Step 3: Remove Duplicates
storm.drop_duplicates(inplace=True)

# Step 4: Remove Impossible Values
storm = storm[
    (storm["temperature"] >= -20) &
    (storm["temperature"] <= 60) &
    (storm["humidity"] >= 0) &
    (storm["humidity"] <= 100) &
    (storm["rainfall"] >= 0) &
    (storm["wind_speed"] >= 0) &
    (storm["pressure"] >= 850) &
    (storm["pressure"] <= 1100)
]

# Step 5: Fill Missing Values
storm["temperature"] = storm["temperature"].fillna(storm["temperature"].median())
storm["humidity"] = storm["humidity"].fillna(storm["humidity"].median())
storm["rainfall"] = storm["rainfall"].fillna(0)
storm["wind_speed"] = storm["wind_speed"].fillna(storm["wind_speed"].median())
storm["pressure"] = storm["pressure"].fillna(storm["pressure"].median())

storm = storm[
    (storm["wind_speed"] >= 30) &
    (storm["pressure"] <= 1012) 
].copy()
# Step 6: Add Label
storm["disaster_type"] = "Storm"

# Step 7: Keep Required Columns
storm = storm[
    [
        "temperature",
        "humidity",
        "rainfall",
        "wind_speed",
        "pressure",
        "disaster_type"
    ]
]
# Step 8: Save Dataset
storm.to_csv("cleaned_storm.csv", index=False)

# Step 9: Verify
print("Storm records:", len(storm))
print(storm.head())
print(storm.info())