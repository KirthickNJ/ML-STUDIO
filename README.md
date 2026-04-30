ML Studio – Mobile Machine Learning Workflow Platform
ML Studio is a full-stack mobile application that enables users to perform and understand the complete machine learning lifecycle — from dataset ingestion to model evaluation, explainability, and experiment tracking.
The application is designed to simulate real-world machine learning systems rather than serving as a simple UI demonstration. It integrates data processing, model training, diagnostics, and model management into a single mobile-first platform.
Tech Stack
Frontend
Flutter
Backend
Flask (REST API)
Machine Learning
pandas
scikit-learn
joblib
Architecture
REST-based communication between frontend and backend
Model persistence using joblib and JSON metadata
Experiment logging using JSONL-based storage
Features
Dataset Management
Upload datasets in CSV, Excel, JSON, Parquet, and TXT formats
Built-in sample datasets:
Mall_Customers.csv
Housing.csv
weatherHistory.csv
Dataset metadata:
Row count, column count
Dataset hash
Timestamp and source
Data Exploration
Summary statistics similar to pandas describe()
Dataset structure similar to pandas info()
Data types and memory usage
Duplicate row detection
Missing value visualization
Data Quality Dashboard
Missing value analysis
Duplicate detection
Constant column detection
High-cardinality warnings
Class imbalance alerts
Data leakage warnings
Overall data quality scoring
Model Training
Target column selection
Automatic detection of problem type:
Classification or Regression
Objective-based training:
Classification: Accuracy, F1, Precision, Recall
Regression: R², MAE, RMSE
Supported Algorithms
Classification
Logistic Regression
Random Forest Classifier
Gradient Boosting Classifier
Regression
Linear Regression
Random Forest Regressor
Gradient Boosting Regressor
Training and Evaluation
Train/validation/test split
Cross-validation
Objective-based model ranking
Metrics
Classification
Accuracy
F1 Score (weighted)
Precision (weighted)
Recall (weighted)
Regression
MSE
RMSE
MAE
R² Score
Diagnostics
Confusion matrix (classification)
Threshold tuning analysis
Residual diagnostics (regression)
Model behavior insights
Prediction
User-provided input prediction
Input validation for missing or extra fields
Uses currently active trained model
Explainability
Global feature importance
Local prediction explanations
Model comparison
What-if analysis
JSON input template generation
Model Registry
Store trained models
Activate or delete models
Stage management:
Development
Staging
Production
Rollback support
Experiment Tracking
Logs all training runs
Tracks model ID, parameters, metrics, and dataset hash
Supports re-running previous experiments
