import pandas as pd

# Load Dataset
df = pd.read_csv("flood_dataset.csv")

print("Original Shape:", df.shape)

# Remove Duplicate Rows
df = df.drop_duplicates()

# Fill Missing Values
numeric_columns = df.select_dtypes(include=["int64", "float64"]).columns

for col in numeric_columns:
    df[col] = df[col].fillna(df[col].median())

# Remove Impossible Values
df = df[df["precipitation"] >= 0]

df = df[
    (df["humidity"] >= 0) &
    (df["humidity"] <= 100)
]

df = df[df["soil_moisture"] >= 0]

df = df[df["wind_speed"] >= 0]

# Select Required Columns
df = df[
    [
        "elevation",
        "latitude",
        "longitude",
        "precipitation",
        "pressure",
        "soil_moisture",
        "temperature",
        "wind_speed",
        "humidity",
        "precip_3day_avg",
        "precip_7day_avg",
        "temp_3day_avg",
        "soil_3day_avg",
        "month",
        "is_monsoon",
        "water_area_change",
        "water_area_pct_change",
        "days_since_last_flood",
        "flood_event"
    ]
]

print("\nCleaned Shape:", df.shape)

print("\nFlood Event Counts")
print(df["flood_event"].value_counts())

df.to_csv("cleaned_flood_dataset.csv", index=False)

print("\nDataset saved successfully.")