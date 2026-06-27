
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import warnings
import joblib
import os

from sklearn.model_selection import StratifiedKFold, cross_val_score
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.metrics import (classification_report, confusion_matrix,
                             accuracy_score, f1_score)
from xgboost import XGBClassifier

warnings.filterwarnings("ignore")

# PATHS

BASE_DIR   = os.path.dirname(os.path.abspath(__file__))
TRAIN_CSV  = os.path.join(BASE_DIR, "disaster_prediction_data.csv")
TEST_CSV   = os.path.join(BASE_DIR, "disaster_test_data.csv")
MODEL_DIR  = os.path.join(BASE_DIR, "saved_models")
os.makedirs(MODEL_DIR, exist_ok=True)


# 1. LOAD DATA

print("=" * 60)
print("  DISASTER PREDICTION — TRAINING PIPELINE")
print("=" * 60)

train_df = pd.read_csv(TRAIN_CSV)
test_df  = pd.read_csv(TEST_CSV)

print(f"\nTrain shape : {train_df.shape}")
print(f"Test  shape : {test_df.shape}")
print("\nTrain class distribution:")
print(train_df["disaster_label"].value_counts())
print("\nTest class distribution:")
print(test_df["disaster_label"].value_counts())


# 2. FEATURE ENGINEERING

def engineer_features(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()

    # Datetime → cyclical numeric features
    df["datetime_utc"] = pd.to_datetime(df["datetime_utc"])
    df["month"]        = df["datetime_utc"].dt.month
    df["hour"]         = df["datetime_utc"].dt.hour
    df["day_of_year"]  = df["datetime_utc"].dt.dayofyear
    df["month_sin"]    = np.sin(2 * np.pi * df["month"]       / 12)
    df["month_cos"]    = np.cos(2 * np.pi * df["month"]       / 12)
    df["hour_sin"]     = np.sin(2 * np.pi * df["hour"]        / 24)
    df["hour_cos"]     = np.cos(2 * np.pi * df["hour"]        / 24)
    df["doy_sin"]      = np.sin(2 * np.pi * df["day_of_year"] / 365)
    df["doy_cos"]      = np.cos(2 * np.pi * df["day_of_year"] / 365)
    df.drop(columns=["datetime_utc", "month", "hour", "day_of_year"], inplace=True)

    # Derived physical features
    df["heat_index"]        = df["temperature_c"] + 0.33 * df["humidity_pct"] - 4.0
    df["wind_pressure"]     = df["wind_speed_kmh"] * (1013 - df["pressure_hpa"]).clip(0)
    df["rain_soil_combo"]   = df["rainfall_mm"] * df["soil_moisture_pct"] / 100
    df["temp_humidity"]     = df["temperature_c"] * df["humidity_pct"]
    df["low_pressure_flag"] = (df["pressure_hpa"]  < 980).astype(int)
    df["high_rain_flag"]    = (df["rainfall_mm"]    > 50 ).astype(int)
    df["high_wind_flag"]    = (df["wind_speed_kmh"] > 60 ).astype(int)
    df["high_temp_flag"]    = (df["temperature_c"]  > 35 ).astype(int)

    return df


train_df = engineer_features(train_df)
test_df  = engineer_features(test_df)


# 3. ADD SEVERITY LABEL

SEVERITY_RULES = {
    "Heatwave":    lambda r: "High"   if r["temperature_c"]  > 42
                             else ("Medium" if r["temperature_c"]  > 38 else "Low"),
    "Flood":       lambda r: "High"   if r["rainfall_mm"]     > 120
                             else ("Medium" if r["rainfall_mm"]     > 80 else "Low"),
    "Heavy Rains": lambda r: "High"   if r["rainfall_mm"]     > 80
                             else ("Medium" if r["rainfall_mm"]     > 50 else "Low"),
    "Storm":       lambda r: "High"   if r["wind_speed_kmh"]  > 100
                             else ("Medium" if r["wind_speed_kmh"]  > 70 else "Low"),
    "Normal":      lambda r: "Low",
}

def add_severity(df):
    df["severity"] = df.apply(
        lambda r: SEVERITY_RULES[r["disaster_label"]](r), axis=1
    )
    return df

train_df = add_severity(train_df)
test_df  = add_severity(test_df)

print("\nTrain severity distribution:")
print(train_df["severity"].value_counts())


# 4. ENCODE LABELS

le_type = LabelEncoder()
le_sev  = LabelEncoder()

train_df["label_enc"]    = le_type.fit_transform(train_df["disaster_label"])
train_df["severity_enc"] = le_sev.fit_transform(train_df["severity"])
test_df["label_enc"]     = le_type.transform(test_df["disaster_label"])
test_df["severity_enc"]  = le_sev.transform(test_df["severity"])

print("\nDisaster type classes :", list(le_type.classes_))
print("Severity classes      :", list(le_sev.classes_))


# 5. PREPARE X / y

DROP_COLS    = ["disaster_label", "severity", "label_enc", "severity_enc"]
FEATURE_COLS = [c for c in train_df.columns if c not in DROP_COLS]

X_train = train_df[FEATURE_COLS]
X_test  = test_df[FEATURE_COLS]

y_type_train = train_df["label_enc"]
y_type_test  = test_df["label_enc"]
y_sev_train  = train_df["severity_enc"]
y_sev_test   = test_df["severity_enc"]

print(f"\nFeatures used ({len(FEATURE_COLS)}): {FEATURE_COLS}")

scaler     = StandardScaler()
X_train_sc = scaler.fit_transform(X_train)
X_test_sc  = scaler.transform(X_test)


# 6. DEFINE MODELS

def get_models():
    return {
        "RandomForest": RandomForestClassifier(
            n_estimators=300, max_depth=None,
            min_samples_leaf=2, class_weight="balanced",
            random_state=42, n_jobs=-1
        ),
        "GradientBoosting": GradientBoostingClassifier(
            n_estimators=200, learning_rate=0.08,
            max_depth=5, subsample=0.8, random_state=42
        ),
        "XGBoost": XGBClassifier(
            n_estimators=300, learning_rate=0.05,
            max_depth=6, subsample=0.8, colsample_bytree=0.8,
            eval_metric="mlogloss", random_state=42, verbosity=0
        ),
    }

cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)


# 7. TRAIN — DISASTER TYPE

print("\n" + "=" * 60)
print("  TRAINING — DISASTER TYPE CLASSIFIER")
print("=" * 60)

best_model_type = None
best_f1_type    = 0

for name, model in get_models().items():
    cv_scores = cross_val_score(
        model, X_train_sc, y_type_train,
        cv=cv, scoring="f1_weighted", n_jobs=-1
    )
    model.fit(X_train_sc, y_type_train)
    y_pred  = model.predict(X_test_sc)
    test_f1 = f1_score(y_type_test, y_pred, average="weighted")

    print(f"\n{name}")
    print(f"  CV F1 (5-fold) : {cv_scores.mean():.4f} ± {cv_scores.std():.4f}")
    print(f"  Test  F1       : {test_f1:.4f}")
    print(f"  Test  Accuracy : {accuracy_score(y_type_test, y_pred):.4f}")

    if test_f1 > best_f1_type:
        best_f1_type    = test_f1
        best_model_type = model
        best_name_type  = name

print(f"\n✔ Best model (Type): {best_name_type}  F1={best_f1_type:.4f}")

y_pred_type = best_model_type.predict(X_test_sc)
print("\n── Classification Report (Disaster Type) ──")
print(classification_report(y_type_test, y_pred_type, target_names=le_type.classes_))


# 8. TRAIN — SEVERITY

print("\n" + "=" * 60)
print("  TRAINING — SEVERITY CLASSIFIER")
print("=" * 60)

best_model_sev = None
best_f1_sev    = 0

for name, model in get_models().items():
    cv_scores = cross_val_score(
        model, X_train_sc, y_sev_train,
        cv=cv, scoring="f1_weighted", n_jobs=-1
    )
    model.fit(X_train_sc, y_sev_train)
    y_pred  = model.predict(X_test_sc)
    test_f1 = f1_score(y_sev_test, y_pred, average="weighted")

    print(f"\n{name}")
    print(f"  CV F1 (5-fold) : {cv_scores.mean():.4f} ± {cv_scores.std():.4f}")
    print(f"  Test  F1       : {test_f1:.4f}")

    if test_f1 > best_f1_sev:
        best_f1_sev    = test_f1
        best_model_sev = model
        best_name_sev  = name

print(f"\n✔ Best model (Severity): {best_name_sev}  F1={best_f1_sev:.4f}")

y_pred_sev = best_model_sev.predict(X_test_sc)
print("\n── Classification Report (Severity) ──")
print(classification_report(y_sev_test, y_pred_sev, target_names=le_sev.classes_))


# 9. SAVE ALL ARTIFACTS → saved_models/

joblib.dump(best_model_type, os.path.join(MODEL_DIR, "model_disaster_type.pkl"))
joblib.dump(best_model_sev,  os.path.join(MODEL_DIR, "model_severity.pkl"))
joblib.dump(scaler,          os.path.join(MODEL_DIR, "scaler.pkl"))
joblib.dump(le_type,         os.path.join(MODEL_DIR, "label_encoder_type.pkl"))
joblib.dump(le_sev,          os.path.join(MODEL_DIR, "label_encoder_severity.pkl"))
joblib.dump(FEATURE_COLS,    os.path.join(MODEL_DIR, "feature_cols.pkl"))

print(f"\n✔ Artifacts saved to '{MODEL_DIR}/'")
print("   model_disaster_type.pkl")
print("   model_severity.pkl")
print("   scaler.pkl")
print("   label_encoder_type.pkl")
print("   label_encoder_severity.pkl")
print("   feature_cols.pkl")


# 10. EVALUATION PLOTS → saved_models/

fig, axes = plt.subplots(1, 2, figsize=(14, 5))

cm = confusion_matrix(y_type_test, y_pred_type)
sns.heatmap(cm, annot=True, fmt="d", cmap="Blues",
            xticklabels=le_type.classes_,
            yticklabels=le_type.classes_, ax=axes[0])
axes[0].set_title("Confusion Matrix — Disaster Type", fontweight="bold")
axes[0].set_xlabel("Predicted")
axes[0].set_ylabel("Actual")

if hasattr(best_model_type, "feature_importances_"):
    fi = pd.Series(best_model_type.feature_importances_, index=FEATURE_COLS)
    fi.nlargest(15).sort_values().plot(kind="barh", ax=axes[1], color="steelblue")
    axes[1].set_title("Top 15 Feature Importances", fontweight="bold")
    axes[1].set_xlabel("Importance Score")

plt.tight_layout()
plot_path = os.path.join(MODEL_DIR, "evaluation_plots.png")
plt.savefig(plot_path, dpi=150, bbox_inches="tight")
plt.show()
print(f"\n✔ Plot saved → {plot_path}")
print("\n✔ Training complete.")
