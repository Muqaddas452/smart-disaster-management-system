import pandas as pd

heatwave = pd.read_csv("heatwave.csv")

# Step 2: Rename Columns

heatwave.rename(columns={
    "temperature_celsius": "temperature",
    "precip_mm": "rainfall",
    "wind_kph": "wind_speed",
    "pressure_mb": "pressure"
}, inplace=True)

# Remove extra spaces from column names
heatwave.columns = heatwave.columns.str.strip()

# Step 3: Remove Duplicates
heatwave.drop_duplicates(inplace=True)

# Step 4: Remove Impossible Values

heatwave = heatwave[
    (heatwave["temperature"] >= -20) &
    (heatwave["temperature"] <= 60)
]
heatwave = heatwave[
    (heatwave["humidity"] >= 0) &
    (heatwave["humidity"] <= 100)
]
heatwave = heatwave[
    heatwave["rainfall"] >= 0
]
heatwave = heatwave[
    heatwave["wind_speed"] >= 0
]
heatwave = heatwave[
    (heatwave["pressure"] >= 850) &
    (heatwave["pressure"] <= 1100)
]
# Step 5: Handle Missing Values
heatwave["temperature"] = heatwave["temperature"].fillna(
    heatwave["temperature"].median()
)
heatwave["humidity"] = heatwave["humidity"].fillna(
    heatwave["humidity"].median()
)
heatwave["rainfall"] = heatwave["rainfall"].fillna(0)

heatwave["wind_speed"] = heatwave["wind_speed"].fillna(
    heatwave["wind_speed"].median()
)
heatwave["pressure"] = heatwave["pressure"].fillna(
    heatwave["pressure"].median()
)
# Step 6: Keep Heatwave Records
heatwave = heatwave[
    (heatwave["temperature"] >= 40) &
    (heatwave["humidity"] <= 35) &
    (heatwave["rainfall"] <= 2)
].copy()

# Step 7: Add Label
heatwave["disaster_type"] = "Heatwave"
heatwave = heatwave[
    [
        "temperature",
        "humidity",
        "rainfall",
        "wind_speed",
        "pressure",
        "disaster_type"
    ]
]

heatwave.to_csv("cleaned_heatwave.csv", index=False)

print("Number of records:", len(heatwave))
print(heatwave.head())
print(heatwave.info())