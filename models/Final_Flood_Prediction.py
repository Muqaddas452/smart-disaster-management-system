import pandas as pd
import joblib
import numpy as np

from sklearn.model_selection import train_test_split
from sklearn.model_selection import cross_val_score, StratifiedKFold
from xgboost import XGBClassifier
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix
)

# Load Cleaned Dataset
df = pd.read_csv("combined_flood_dataset.csv")

print(df["flood_event"].value_counts())

# Replace Infinity values with NaN
df.replace([np.inf, -np.inf], np.nan, inplace=True)

# Fill NaN values with median
df.fillna(df.median(numeric_only=True), inplace=True)

X = df[
    [
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
         "is_monsoon"
    ]
]

# Target

y = df["flood_event"]
import numpy as np

print("Checking for Infinity values...\n")

for col in X.columns:
    if np.isinf(X[col]).any():
        print(col, "contains Infinity")

print("\nMaximum values:")
print(X.max())

print("\nMinimum values:")
print(X.min())

# Cross Validation
cv_model = XGBClassifier(
    n_estimators=300,
    max_depth=6,
    learning_rate=0.05,
    subsample=0.8,
    colsample_bytree=0.8,
    random_state=42,
    eval_metric="logloss"
)
cv = StratifiedKFold(
    n_splits=5,
    shuffle=True,
    random_state=42
)
scores = cross_val_score(
    estimator=cv_model,
    X=X,
    y=y,
    cv=cv,
    scoring="accuracy",
    n_jobs=-1
)
print("Accuracy of each fold:")
print(scores)

print("\nMean Accuracy:", round(scores.mean(), 4))

print("Standard Deviation:", round(scores.std(), 4))

# Train Test Split
X_train, X_test, y_train, y_test = train_test_split(
    X,
    y,
    test_size=0.20,
    stratify=y,
    random_state=42
)

# Train
model = XGBClassifier(
    n_estimators=300,
    max_depth=6,
    learning_rate=0.05,
    subsample=0.8,
    colsample_bytree=0.8,
    scale_pos_weight=2.09,
    random_state=42,
    eval_metric="logloss"
)

model.fit(X_train, y_train)

# Prediction
y_pred = model.predict(X_test)

print("\nAccuracy")

print(accuracy_score(y_test, y_pred))

print("\nClassification Report")

print(classification_report(y_test, y_pred))

print("\nConfusion Matrix")

print(confusion_matrix(y_test, y_pred))

importance = pd.DataFrame(
    {
        "Feature": X.columns,
        "Importance": model.feature_importances_
    }
)

print("\nFeature Importance")

print(importance.sort_values(by="Importance", ascending=False))

joblib.dump(model, "flood_model.pkl")

