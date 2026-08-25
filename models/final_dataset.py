import pandas as pd

# Load datasets
data1 = pd.read_csv("cleaned_flood_dataset.csv")
data2 = pd.read_csv("flood_dataset2.csv")

# Merge
combined = pd.concat([data1, data2], ignore_index=True)

# Shuffle
combined = combined.sample(frac=1, random_state=42).reset_index(drop=True)

# Save
combined.to_csv("combined_flood_dataset.csv", index=False)

print("data1 records:", len(data1))
print("data2 records:", len(data2))
print("Combined records:", len(combined))

combined = pd.read_csv("combined_flood_dataset.csv")

print(combined["flood_event"].value_counts())
