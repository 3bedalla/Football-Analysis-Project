import sqlite3
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor, RandomForestClassifier
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score, accuracy_score
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline
import joblib

# -------------------------
# 1) Connect to SQLite and load data
# -------------------------
db_path = r"C:\Users\3beda\OneDrive\Desktop\GitProjects\FootballAnalysisProject\football.db"

conn = sqlite3.connect(db_path)
tables = pd.read_sql_query("SELECT name FROM sqlite_master WHERE type='table';", conn)
print("Tables in DB:", tables)

df = pd.read_sql_query("SELECT * FROM team_season_features;", conn)
conn.close()

# -------------------------
# 2) Preprocess and feature creation
# -------------------------
df = df.sort_values(['team', 'season']).reset_index(drop=True)

# Create lag features
lagged = df.groupby('team').shift(1).add_prefix('lag1_')
df_lag = pd.concat([df, lagged], axis=1)

# Default lag feature columns
lag_feature_cols = [
    'lag1_points',
    'lag1_avg_xg', 'lag1_avg_shots', 'lag1_avg_goals',
    'lag1_avg_possession', 'lag1_avg_pass_accuracy', 'lag1_goal_rate', 'lag1_top_form_pct',
    'lag1_matches_played'
]

# Drop rows where lag features exist
df_lag_clean = df_lag.dropna(subset=lag_feature_cols)

# Handle single-season dataset
if df_lag_clean.shape[0] == 0:
    print("Only one season detected. Using current season stats as features.")
    feature_cols = [
        'points', 'avg_xg', 'avg_shots', 'avg_goals',
        'avg_possession', 'avg_pass_accuracy', 'goal_rate', 'top_form_pct', 'matches_played'
    ]
    df_lag_clean = df.copy()
    df_lag_clean = df_lag_clean.rename(columns={c: c for c in feature_cols})
    use_lag_features = False
else:
    feature_cols = lag_feature_cols
    use_lag_features = True

X = df_lag_clean[feature_cols].astype(float)
y = df_lag_clean['points'].astype(float)

# -------------------------
# 3) Train/test split
# -------------------------
max_season = df_lag_clean['season'].max()
train_mask = df_lag_clean['season'] < max_season
test_mask = df_lag_clean['season'] == max_season

X_train, X_test = X[train_mask], X[test_mask]
y_train, y_test = y[train_mask], y[test_mask]

# If no training data (single-season), use all data for training
if X_train.shape[0] == 0:
    X_train = X.copy()
    y_train = y.copy()
    X_test = pd.DataFrame()
    y_test = pd.Series()
    print("Only one season available. Using all data for training, skipping evaluation.")

print(f"Training samples: {X_train.shape[0]}, Test samples: {X_test.shape[0]}")

# Baseline
if X_test.shape[0] > 0 and use_lag_features:
    baseline_pred = X_test['lag1_points'].values
    print('Baseline MAE:', mean_absolute_error(y_test, baseline_pred))
else:
    print("Warning: Test set is empty or no lag features. Skipping baseline evaluation.")

# -------------------------
# 4) Train RandomForestRegressor
# -------------------------
pipeline = Pipeline([
    ('scaler', StandardScaler()),
    ('model', RandomForestRegressor(n_estimators=200, random_state=42, n_jobs=-1))
])

pipeline.fit(X_train, y_train)

if X_test.shape[0] > 0:
    y_pred = pipeline.predict(X_test)
    print('RF MAE:', mean_absolute_error(y_test, y_pred))
    print('RF RMSE:', mean_squared_error(y_test, y_pred, squared=False))
    print('RF R2:', r2_score(y_test, y_pred))

    importances = pipeline.named_steps['model'].feature_importances_
    feat_importance = pd.Series(importances, index=feature_cols).sort_values(ascending=False)
    print('Feature importances:\n', feat_importance)

# -------------------------
# 5) Predict next season
# -------------------------
latest_season = df['season'].max()
latest = df[df['season'] == latest_season].copy()

if latest.shape[0] > 0:
    if use_lag_features:
        latest_feats = latest[['team', 'points', 'avg_xg', 'avg_shots', 'avg_goals',
                               'avg_possession', 'avg_pass_accuracy', 'goal_rate', 'top_form_pct',
                               'matches_played']]

        latest_feats = latest_feats.rename(columns={
            'points': 'lag1_points',
            'avg_xg': 'lag1_avg_xg',
            'avg_shots': 'lag1_avg_shots',
            'avg_goals': 'lag1_avg_goals',
            'avg_possession': 'lag1_avg_possession',
            'avg_pass_accuracy': 'lag1_avg_pass_accuracy',
            'goal_rate': 'lag1_goal_rate',
            'top_form_pct': 'lag1_top_form_pct',
            'matches_played': 'lag1_matches_played'
        })
    else:
        latest_feats = latest[feature_cols].copy()

    X_next = latest_feats[feature_cols].astype(float)
    pred_next_points = pipeline.predict(X_next)

    pred_df = pd.DataFrame({
        'team': latest['team'].values,
        'pred_points_next_season': np.round(pred_next_points, 1)
    }).sort_values('pred_points_next_season', ascending=False)

    print('Predicted points next season:\n', pred_df)
else:
    pred_df = pd.DataFrame()
    print("Warning: No data for latest season to predict next season points.")

# -------------------------
# 6) Save model
# -------------------------
joblib.dump(pipeline, 'rf_points_predictor.joblib')

# -------------------------
# 7) Optional classification (Top 4 prediction)
# -------------------------
df_lag_clean['is_top4'] = (df_lag_clean.groupby('season')['points']
                            .rank(method='first', ascending=False) <= 4).astype(int)

clf_pipe = Pipeline([
    ('scaler', StandardScaler()),
    ('clf', RandomForestClassifier(n_estimators=200, random_state=42, class_weight='balanced', n_jobs=-1))
])

clf_pipe.fit(X_train, df_lag_clean.loc[train_mask, 'is_top4'] if use_lag_features else df_lag_clean['is_top4'])

if X_test.shape[0] > 0:
    proba = clf_pipe.predict_proba(X_test)[:, 1]
    print('Top4 Classifier Accuracy:',
          accuracy_score(df_lag_clean.loc[test_mask, 'is_top4'], clf_pipe.predict(X_test)))

    proba_next = clf_pipe.predict_proba(X_next)[:, 1]
    pred_df['prob_top4_next'] = np.round(proba_next, 3)

    print(pred_df.head(10))
else:
    print("Warning: Skipping Top 4 evaluation due to empty test set.")
