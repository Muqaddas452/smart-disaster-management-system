import pandas as pd
import joblib
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix
)
from sklearn.model_selection import cross_val_score
import numpy as np

heatwave = pd.read_csv("cleaned_heatwave.csv")
normal = pd.read_csv("cleaned_normal.csv")
storm = pd.read_csv("cleaned_storm.csv")
heavy_rain = pd.read_csv("cleaned_rainfall.csv")

# Merge
dataset = pd.concat(
    [heatwave, normal, storm, heavy_rain],
    ignore_index=True
)

# Shuffle
dataset = dataset.sample(frac=1, random_state=42).reset_index(drop=True)

# Save merged dataset
dataset.to_csv("final_disaster_dataset.csv", index=False)

print(dataset["disaster_type"].value_counts())
print(dataset.shape)

# Features & Target
X = dataset[
    [
        "temperature",
        "humidity",
        "rainfall",
        "wind_speed",
        "pressure"
    ]
]

y = dataset["disaster_type"]

# Encode Labels
label_encoder = LabelEncoder()
y = label_encoder.fit_transform(y)

# Save Label Encoder
joblib.dump(label_encoder, "label_encoder.pkl")

cv_model = RandomForestClassifier(
    n_estimators=300,
    max_depth=15,
    min_samples_split=5,
    min_samples_leaf=2,
    class_weight="balanced",
    random_state=42
)

scores = cross_val_score(
    cv_model,
    X,
    y,
    cv=5,
    scoring="accuracy"
)

print("\n5-Fold Cross Validation")
print("Accuracy of each fold:", scores)
print("Mean Accuracy:", np.mean(scores))
print("Standard Deviation:", np.std(scores))

# Train-Test Split
X_train, X_test, y_train, y_test = train_test_split(
    X,
    y,
    test_size=0.2,
    random_state=42,
    stratify=y
)
# Train Random Forest
model = RandomForestClassifier(
    n_estimators=300,
    max_depth=15,
    min_samples_split=5,
    min_samples_leaf=2,
    random_state=42,
    class_weight="balanced"
)

model.fit(X_train, y_train)

# Prediction
y_pred = model.predict(X_test)

# Evaluation
print("Accuracy:", accuracy_score(y_test, y_pred))

print("\nClassification Report")
print(classification_report(y_test, y_pred))

print("\nConfusion Matrix")
print(confusion_matrix(y_test, y_pred))

# Feature Importance
importance = pd.DataFrame({
    "Feature": X.columns,
    "Importance": model.feature_importances_
})

print("\nFeature Importance")
print(importance.sort_values(by="Importance", ascending=False))

# Save Model
joblib.dump(model, "weather_disaster_model.pkl")

print("\nModel saved successfully.")

