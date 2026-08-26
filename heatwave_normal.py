import pandas as pd
new= pd.read_csv("Heatwave_normal_dataset.csv")
new.rename(columns={
    "temperature_celsius": "temperature",
    "precip_mm": "rainfall",
    "wind_kph": "wind_speed",
    "pressure_mb": "pressure"
}, inplace=True)
heatwave = new[
    (new["temperature"] >= 40) &
    (new["humidity"] <= 30) &
    (new["rainfall"] <= 2)
].copy()

normal = new[
    (new["temperature"] >= 20) &
    (new["temperature"] <= 35) &
    (new["humidity"] >= 30) &
    (new["humidity"] <= 70) &
    (new["rainfall"] <= 10)
].copy()

heatwave["disaster_type"] = "Heatwave"
normal["disaster_type"] = "Normal"
normal = normal.sample(n=3000, random_state=42)
heatwave.to_csv("heatwave.csv", index=False)
normal.to_csv("normal.csv", index=False)

print("Heatwave records:", len(heatwave))
print("Normal records:", len(normal))