from __future__ import annotations

import hashlib
import json
import os
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, Optional

from flask import Flask, jsonify, request
from flask_cors import CORS
import joblib
import pandas as pd

from model_utils import (
    analyze_data_quality,
    explain_model,
    make_prediction,
    recommend_algorithms,
    train_model,
)

app = Flask(__name__)
CORS(app)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STORAGE_DIR = os.path.join(BASE_DIR, 'storage')
REGISTRY_DIR = os.path.join(STORAGE_DIR, 'models_registry')
ACTIVE_MODEL_POINTER = os.path.join(STORAGE_DIR, 'active_model.json')
EXPERIMENT_LOG_FILE = os.path.join(STORAGE_DIR, 'experiments.jsonl')

# Runtime state
_df: Optional[pd.DataFrame] = None
_active_model = None
_active_model_meta: Optional[Dict[str, Any]] = None
_active_model_id: Optional[str] = None
_dataset_hash: Optional[str] = None
_dataset_profile: Optional[Dict[str, Any]] = None
_dataset_uploaded_at: Optional[str] = None
_dataset_name: Optional[str] = None
_dataset_source: Optional[str] = None


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _ensure_storage() -> None:
    os.makedirs(STORAGE_DIR, exist_ok=True)
    os.makedirs(REGISTRY_DIR, exist_ok=True)


def _model_paths(model_id: str) -> Dict[str, str]:
    return {
        'model_file': os.path.join(REGISTRY_DIR, f'{model_id}.joblib'),
        'meta_file': os.path.join(REGISTRY_DIR, f'{model_id}.meta.json'),
    }


def _write_json(path: str, payload: Dict[str, Any]) -> None:
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(payload, f, indent=2)


def _read_json(path: str) -> Dict[str, Any]:
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)


def _append_experiment_log(entry: Dict[str, Any]) -> None:
    _ensure_storage()
    with open(EXPERIMENT_LOG_FILE, 'a', encoding='utf-8') as f:
        f.write(json.dumps(entry) + '\n')


def _read_experiment_log() -> list[Dict[str, Any]]:
    _ensure_storage()
    if not os.path.exists(EXPERIMENT_LOG_FILE):
        return []

    items: list[Dict[str, Any]] = []
    with open(EXPERIMENT_LOG_FILE, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                items.append(json.loads(line))
            except Exception:
                continue

    items.sort(key=lambda x: x.get('created_at', ''), reverse=True)
    return items


def _list_registry_entries() -> list[Dict[str, Any]]:
    _ensure_storage()
    items = []
    for name in os.listdir(REGISTRY_DIR):
        if not name.endswith('.meta.json'):
            continue
        try:
            meta = _read_json(os.path.join(REGISTRY_DIR, name))
            items.append(meta)
        except Exception:
            continue

    items.sort(key=lambda x: x.get('created_at', ''), reverse=True)
    return items


def _load_model(model_id: str) -> bool:
    global _active_model, _active_model_meta, _active_model_id

    paths = _model_paths(model_id)
    if not os.path.exists(paths['model_file']) or not os.path.exists(paths['meta_file']):
        return False

    try:
        _active_model = joblib.load(paths['model_file'])
        _active_model_meta = _read_json(paths['meta_file'])
        _active_model_id = model_id
        return True
    except Exception:
        _active_model = None
        _active_model_meta = None
        _active_model_id = None
        return False


def _set_active_model(model_id: Optional[str]) -> bool:
    global _active_model_id, _active_model, _active_model_meta

    _ensure_storage()

    if model_id is None:
        if os.path.exists(ACTIVE_MODEL_POINTER):
            os.remove(ACTIVE_MODEL_POINTER)
        _active_model_id = None
        _active_model = None
        _active_model_meta = None
        return True

    if not _load_model(model_id):
        return False

    _write_json(ACTIVE_MODEL_POINTER, {'active_model_id': model_id, 'updated_at': _utc_now()})
    return True


def _load_active_from_pointer() -> bool:
    if not os.path.exists(ACTIVE_MODEL_POINTER):
        return False

    try:
        payload = _read_json(ACTIVE_MODEL_POINTER)
        model_id = payload.get('active_model_id')
        if not model_id:
            return False
        return _load_model(str(model_id))
    except Exception:
        return False


def _dataset_fingerprint(df: pd.DataFrame) -> str:
    hashed = pd.util.hash_pandas_object(df, index=True).values
    digest = hashlib.sha256(hashed.tobytes()).hexdigest()
    return digest


def _dataset_profile_payload(df: pd.DataFrame) -> Dict[str, Any]:
    numeric = df.select_dtypes(include=['number', 'bool'])
    numeric_profile: Dict[str, Dict[str, float]] = {}
    for col in numeric.columns:
        s = numeric[col]
        numeric_profile[col] = {
            'mean': float(s.mean()) if not s.dropna().empty else 0.0,
            'std': float(s.std()) if not s.dropna().empty else 0.0,
            'p50': float(s.quantile(0.5)) if not s.dropna().empty else 0.0,
        }

    categorical_profile: Dict[str, Dict[str, float]] = {}
    for col in df.select_dtypes(exclude=['number', 'bool']).columns:
        vc = df[col].astype(str).value_counts(normalize=True, dropna=False).head(5)
        categorical_profile[col] = {str(k): float(v) for k, v in vc.items()}

    return {
        'rows': int(len(df)),
        'columns': int(df.shape[1]),
        'numeric': numeric_profile,
        'categorical_top_values': categorical_profile,
    }


def _dataset_summary_payload() -> Dict[str, Any]:
    if _df is None:
        return {'has_dataset_loaded': False}

    return {
        'has_dataset_loaded': True,
        'dataset_hash': _dataset_hash,
        'dataset_uploaded_at': _dataset_uploaded_at,
        'dataset_name': _dataset_name,
        'dataset_source': _dataset_source,
        'rows': int(len(_df)),
        'columns': int(_df.shape[1]),
    }


def _set_loaded_dataset(df: pd.DataFrame, dataset_name: str, source: str) -> None:
    global _df, _dataset_hash, _dataset_profile, _dataset_uploaded_at, _dataset_name, _dataset_source

    _df = df
    _dataset_hash = _dataset_fingerprint(df)
    _dataset_profile = _dataset_profile_payload(df)
    _dataset_uploaded_at = _utc_now()
    _dataset_name = dataset_name
    _dataset_source = source
    _set_active_model(None)


def _builtin_dataset_catalog() -> list[Dict[str, Any]]:
    return [
        {
            'key': 'mall_customers',
            'title': 'Mall Customers',
            'description': 'Customer segmentation style dataset for exploration and target-based modeling.',
            'problem_type': 'exploration',
            'rows': 200,
            'columns': 5,
        },
        {
            'key': 'housing',
            'title': 'Housing',
            'description': 'Housing prices dataset for regression workflows and feature analysis.',
            'problem_type': 'regression',
            'rows': 545,
            'columns': 13,
        },
        {
            'key': 'weather_history',
            'title': 'Weather History',
            'description': 'Large weather dataset for forecasting-style exploration and prediction tasks.',
            'problem_type': 'time-series',
            'rows': 96453,
            'columns': 12,
        },
    ]


def _load_builtin_dataset(key: str) -> pd.DataFrame:
    if key == 'mall_customers':
        path = os.path.join(BASE_DIR, 'sample_data', 'Mall_Customers.csv')
        return pd.read_csv(path)

    if key == 'housing':
        path = os.path.join(BASE_DIR, 'sample_data', 'Housing.csv')
        return pd.read_csv(path)

    if key == 'weather_history':
        path = os.path.join(BASE_DIR, 'sample_data', 'weatherHistory.csv')
        return pd.read_csv(path)

    raise ValueError('Unknown built-in dataset')


def _drift_report(current: Dict[str, Any], baseline: Dict[str, Any]) -> Dict[str, Any]:
    numeric_alerts = []
    baseline_numeric = baseline.get('numeric', {}) if isinstance(baseline, dict) else {}

    for col, cur in (current.get('numeric', {}) or {}).items():
        base = baseline_numeric.get(col)
        if not base:
            continue

        base_mean = float(base.get('mean', 0.0))
        cur_mean = float(cur.get('mean', 0.0))
        base_std = abs(float(base.get('std', 0.0)))

        denom = base_std if base_std > 1e-8 else max(abs(base_mean), 1.0)
        z = abs(cur_mean - base_mean) / denom
        if z >= 1.0:
            numeric_alerts.append(
                {
                    'column': col,
                    'baseline_mean': base_mean,
                    'current_mean': cur_mean,
                    'z_shift': float(round(z, 4)),
                }
            )

    numeric_alerts.sort(key=lambda x: x['z_shift'], reverse=True)

    return {
        'drift_detected': len(numeric_alerts) > 0,
        'numeric_mean_shift_alerts': numeric_alerts[:20],
        'summary': f"{len(numeric_alerts)} numeric features show significant mean shift.",
    }


def _persist_trained_model(model, meta: Dict[str, Any], diagnostics: Dict[str, Any]) -> str:
    _ensure_storage()

    model_id = str(uuid.uuid4())
    created_at = _utc_now()

    registry_meta = {
        'model_id': model_id,
        'name': meta.get('name') or f"{meta.get('algorithm', 'model')}::{created_at}",
        'created_at': created_at,
        'algorithm': meta.get('algorithm'),
        'problem_type': meta.get('problem_type'),
        'target_column': meta.get('target_column'),
        'feature_columns': meta.get('feature_columns', []),
        'feature_schema': meta.get('feature_schema', {}),
        'numeric_features': meta.get('numeric_features', []),
        'categorical_features': meta.get('categorical_features', []),
        'metrics': meta.get('metrics', {}),
        'split': meta.get('split', {}),
        'train_params': meta.get('train_params', {}),
        'objective': meta.get('objective', 'balanced'),
        'dataset_hash': _dataset_hash,
        'dataset_name': _dataset_name,
        'dataset_source': _dataset_source,
        'dataset_profile': _dataset_profile,
        'diagnostics': diagnostics,
        'stage': 'development',
        'approval': {
            'status': 'pending',
            'updated_at': created_at,
            'approved_by': None,
            'notes': None,
        },
    }

    paths = _model_paths(model_id)
    joblib.dump(model, paths['model_file'])
    _write_json(paths['meta_file'], registry_meta)

    _set_active_model(model_id)
    return model_id


def _update_model_meta(model_id: str, patch: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    paths = _model_paths(model_id)
    if not os.path.exists(paths['meta_file']):
        return None

    payload = _read_json(paths['meta_file'])
    payload.update(patch)
    _write_json(paths['meta_file'], payload)

    if _active_model_id == model_id:
        _load_model(model_id)

    return payload


def _require_dataset() -> Optional[Any]:
    if _df is None:
        return jsonify({'error': 'Upload dataset first'}), 400
    return None


def _current_model_ready() -> bool:
    if _active_model is not None and _active_model_meta is not None:
        return True
    return _load_active_from_pointer()


def _read_uploaded_dataset(file_obj) -> pd.DataFrame:
    filename = (file_obj.filename or '').lower()

    if filename.endswith('.csv') or filename.endswith('.txt'):
        return pd.read_csv(file_obj)

    if filename.endswith('.xlsx') or filename.endswith('.xls'):
        try:
            return pd.read_excel(file_obj)
        except ImportError as e:
            raise ValueError('Excel support requires openpyxl. Install openpyxl in backend env.') from e

    if filename.endswith('.json'):
        return pd.read_json(file_obj)

    if filename.endswith('.parquet'):
        try:
            return pd.read_parquet(file_obj)
        except ImportError as e:
            raise ValueError('Parquet support requires pyarrow or fastparquet in backend env.') from e

    raise ValueError('Unsupported file type. Use CSV, XLSX, XLS, JSON, PARQUET, or TXT.')


@app.route('/')
def home():
    return jsonify({'message': 'ML Backend Running'})


@app.route('/upload', methods=['POST'])
def upload_file():
    global _df, _dataset_hash, _dataset_profile, _dataset_uploaded_at, _dataset_name, _dataset_source

    if 'file' not in request.files:
        return jsonify({'error': 'No file uploaded'}), 400

    file = request.files['file']

    try:
        _set_loaded_dataset(
            _read_uploaded_dataset(file),
            file.filename or 'uploaded_dataset',
            'upload',
        )

        return jsonify(
            {
                'message': 'File uploaded successfully',
                'columns': _df.columns.tolist(),
                'rows': len(_df),
                'dataset_hash': _dataset_hash,
                'dataset_name': _dataset_name,
                'dataset_uploaded_at': _dataset_uploaded_at,
                'dataset_source': _dataset_source,
            }
        )
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/samples', methods=['GET'])
def builtin_samples():
    return jsonify({'samples': _builtin_dataset_catalog()})


@app.route('/samples/load', methods=['POST'])
def load_builtin_sample():
    data = request.json or {}
    sample_key = str(data.get('sample_key') or '').strip()

    if not sample_key:
        return jsonify({'error': 'sample_key is required'}), 400

    try:
        df = _load_builtin_dataset(sample_key)
        sample_meta = next(
            (item for item in _builtin_dataset_catalog() if item['key'] == sample_key),
            None,
        )
        dataset_name = sample_meta['title'] if sample_meta else sample_key
        _set_loaded_dataset(df, dataset_name, f'builtin:{sample_key}')

        return jsonify(
            {
                'message': f'Sample dataset "{dataset_name}" loaded',
                'sample_key': sample_key,
                'dataset_name': _dataset_name,
                'dataset_source': _dataset_source,
                'dataset_hash': _dataset_hash,
                'dataset_uploaded_at': _dataset_uploaded_at,
                'rows': len(_df),
                'columns': _df.columns.tolist(),
            }
        )
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/overview', methods=['GET'])
def overview():
    guard = _require_dataset()
    if guard:
        return guard

    summary = _df.describe(include='all').fillna('').to_dict()

    dtypes = {col: str(dtype) for col, dtype in _df.dtypes.items()}
    null_counts = _df.isnull().sum().to_dict()
    non_null_counts = _df.notnull().sum().to_dict()

    numeric_df = _df.select_dtypes(include='number')
    numeric_profiles = []
    if not numeric_df.empty:
        numeric_stats = numeric_df.describe().to_dict()
        for col, values in numeric_stats.items():
            numeric_profiles.append(
                {
                    'column': col,
                    'min': float(values.get('min', 0) or 0),
                    'mean': float(values.get('mean', 0) or 0),
                    'max': float(values.get('max', 0) or 0),
                    'std': float(values.get('std', 0) or 0),
                }
            )

    missing_chart = [
        {
            'column': col,
            'missing': int(count),
            'missing_pct': float((count / len(_df)) * 100) if len(_df) else 0.0,
        }
        for col, count in null_counts.items()
    ]
    missing_chart.sort(key=lambda item: item['missing'], reverse=True)

    info = {
        'rows': int(len(_df)),
        'columns': int(_df.shape[1]),
        'memory_usage_bytes': int(_df.memory_usage(deep=True).sum()),
        'duplicate_rows': int(_df.duplicated().sum()),
        'dataset_hash': _dataset_hash,
        'dataset_uploaded_at': _dataset_uploaded_at,
        'dataset_name': _dataset_name,
        'dataset_source': _dataset_source,
        'dtypes': dtypes,
        'null_counts': {k: int(v) for k, v in null_counts.items()},
        'non_null_counts': {k: int(v) for k, v in non_null_counts.items()},
        'numeric_columns': numeric_df.columns.tolist(),
        'categorical_columns': [c for c in _df.columns.tolist() if c not in numeric_df.columns.tolist()],
    }

    return jsonify(
        {
            'summary': summary,
            'columns': _df.columns.tolist(),
            'info': info,
            'charts': {
                'missing_values': missing_chart,
                'numeric_profiles': numeric_profiles,
            },
        }
    )


@app.route('/quality', methods=['GET'])
def quality():
    guard = _require_dataset()
    if guard:
        return guard

    target = request.args.get('target_column')
    if target and target not in _df.columns:
        return jsonify({'error': 'Invalid target column'}), 400

    return jsonify(analyze_data_quality(_df, target))


@app.route('/monitor', methods=['GET'])
def monitor():
    guard = _require_dataset()
    if guard:
        return guard

    quality_payload = analyze_data_quality(_df, (_active_model_meta or {}).get('target_column'))

    baseline_profile = (_active_model_meta or {}).get('dataset_profile')
    drift = None
    if baseline_profile and _dataset_profile:
        drift = _drift_report(_dataset_profile, baseline_profile)

    entries = _list_registry_entries()
    by_stage = {'development': 0, 'staging': 0, 'production': 0}
    for m in entries:
        stage = str(m.get('stage') or 'development')
        by_stage[stage] = by_stage.get(stage, 0) + 1

    return jsonify(
        {
            'dataset_hash': _dataset_hash,
            'active_model_id': _active_model_id,
            'registry_by_stage': by_stage,
            'quality': quality_payload,
            'drift': drift,
        }
    )


@app.route('/model/status', methods=['GET'])
def model_status():
    ready = _current_model_ready()
    dataset_summary = _dataset_summary_payload()

    return jsonify(
        {
            'is_trained': bool(ready),
            'has_dataset_loaded': bool(_df is not None),
            'active_model_id': _active_model_id,
            'target_column': (_active_model_meta or {}).get('target_column'),
            'feature_columns': (_active_model_meta or {}).get('feature_columns', []),
            'problem_type': (_active_model_meta or {}).get('problem_type'),
            'algorithm': (_active_model_meta or {}).get('algorithm'),
            **dataset_summary,
            'registry_size': len(_list_registry_entries()),
        }
    )


@app.route('/models', methods=['GET'])
def list_models():
    entries = _list_registry_entries()
    return jsonify({'active_model_id': _active_model_id, 'models': entries})


@app.route('/models/activate', methods=['POST'])
def activate_model():
    data = request.json or {}
    model_id = data.get('model_id')

    if not model_id:
        return jsonify({'error': 'model_id is required'}), 400

    if not _set_active_model(str(model_id)):
        return jsonify({'error': 'Model not found or failed to load'}), 404

    return jsonify({'message': 'Model activated', 'active_model_id': str(model_id)})


@app.route('/models/delete', methods=['POST'])
def delete_model():
    data = request.json or {}
    model_id = data.get('model_id')

    if not model_id:
        return jsonify({'error': 'model_id is required'}), 400

    paths = _model_paths(str(model_id))
    removed = False
    for p in paths.values():
        if os.path.exists(p):
            os.remove(p)
            removed = True

    if _active_model_id == str(model_id):
        _set_active_model(None)

    if not removed:
        return jsonify({'error': 'Model not found'}), 404

    return jsonify({'message': 'Model deleted', 'model_id': str(model_id)})


@app.route('/models/stage', methods=['POST'])
def update_stage():
    data = request.json or {}
    model_id = str(data.get('model_id') or '')
    stage = str(data.get('stage') or '').lower()
    approved_by = data.get('approved_by')
    notes = data.get('notes')

    if not model_id or stage not in {'development', 'staging', 'production'}:
        return jsonify({'error': 'model_id and valid stage are required'}), 400

    updated = _update_model_meta(
        model_id,
        {
            'stage': stage,
            'approval': {
                'status': 'approved' if stage in {'staging', 'production'} else 'pending',
                'updated_at': _utc_now(),
                'approved_by': approved_by,
                'notes': notes,
            },
        },
    )

    if updated is None:
        return jsonify({'error': 'Model not found'}), 404

    return jsonify({'message': f'Model moved to {stage}', 'model': updated})


@app.route('/models/rollback', methods=['POST'])
def rollback_model():
    data = request.json or {}
    model_id = data.get('model_id')

    if not model_id:
        return jsonify({'error': 'model_id is required'}), 400

    if not _set_active_model(str(model_id)):
        return jsonify({'error': 'Model not found'}), 404

    return jsonify({'message': 'Rollback complete. Model activated.', 'active_model_id': str(model_id)})


@app.route('/experiments', methods=['GET'])
def experiments():
    return jsonify({'experiments': _read_experiment_log()})


@app.route('/experiments/rerun', methods=['POST'])
def rerun_experiment():
    guard = _require_dataset()
    if guard:
        return guard

    data = request.json or {}
    experiment_id = str(data.get('experiment_id') or '')

    if not experiment_id:
        return jsonify({'error': 'experiment_id is required'}), 400

    experiments_list = _read_experiment_log()
    selected = next((e for e in experiments_list if str(e.get('experiment_id')) == experiment_id), None)
    if not selected:
        return jsonify({'error': 'Experiment not found'}), 404

    params = selected.get('train_params') or {}
    target_column = str(params.get('target_column') or selected.get('target_column') or '')
    algorithm = params.get('algorithm') or selected.get('algorithm')
    objective = str(params.get('objective') or selected.get('objective') or 'balanced')
    seed = int(params.get('seed') or 42)

    if not target_column:
        return jsonify({'error': 'Experiment missing target_column'}), 400

    try:
        model, primary_metrics, model_meta, recommendation, diagnostics = train_model(
            _df,
            target_column,
            algorithm,
            objective=objective,
            random_state=seed,
        )
        model_meta['name'] = f"rerun::{algorithm}::{_utc_now()}"

        model_id = _persist_trained_model(model, model_meta, diagnostics)

        new_experiment = {
            'experiment_id': str(uuid.uuid4()),
            'rerun_of': experiment_id,
            'created_at': _utc_now(),
            'dataset_hash': _dataset_hash,
            'model_id': model_id,
            'target_column': model_meta['target_column'],
            'problem_type': model_meta['problem_type'],
            'algorithm': model_meta['algorithm'],
            'objective': model_meta.get('objective', objective),
            'metrics': model_meta['metrics'],
            'diagnostics': diagnostics,
            'train_params': model_meta.get('train_params', {}),
        }
        _append_experiment_log(new_experiment)

        return jsonify(
            {
                'message': 'Experiment rerun successfully',
                'model_id': model_id,
                'metrics': primary_metrics,
                'all_metrics': model_meta['metrics'],
                'target_column': model_meta['target_column'],
                'feature_columns': model_meta['feature_columns'],
                'feature_schema': model_meta['feature_schema'],
                'problem_type': model_meta['problem_type'],
                'algorithm': model_meta['algorithm'],
                'diagnostics': diagnostics,
                'recommended_algorithm': recommendation['recommended_algorithm'],
            }
        )
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/recommend', methods=['POST'])
def recommend():
    guard = _require_dataset()
    if guard:
        return guard

    data = request.json or {}
    target_column = data.get('target_column')
    objective = str(data.get('objective') or 'balanced')

    if not target_column:
        return jsonify({'error': 'Target column missing'}), 400

    if target_column not in _df.columns:
        return jsonify({'error': 'Invalid target column'}), 400

    try:
        return jsonify(recommend_algorithms(_df, target_column, objective=objective))
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/train', methods=['POST'])
def train():
    guard = _require_dataset()
    if guard:
        return guard

    data = request.json or {}

    target_column = data.get('target_column')
    selected_algorithm = data.get('algorithm')
    model_name = data.get('model_name')
    objective = str(data.get('objective') or 'balanced')
    seed = int(data.get('seed') or 42)

    if not target_column:
        return jsonify({'error': 'Target column missing'}), 400

    if target_column not in _df.columns:
        return jsonify({'error': 'Invalid target column'}), 400

    try:
        model, primary_metrics, model_meta, recommendation, diagnostics = train_model(
            _df,
            target_column,
            selected_algorithm,
            objective=objective,
            random_state=seed,
        )

        if model_name:
            model_meta['name'] = str(model_name)

        model_id = _persist_trained_model(model, model_meta, diagnostics)

        experiment = {
            'experiment_id': str(uuid.uuid4()),
            'created_at': _utc_now(),
            'dataset_hash': _dataset_hash,
            'model_id': model_id,
            'target_column': model_meta['target_column'],
            'problem_type': model_meta['problem_type'],
            'algorithm': model_meta['algorithm'],
            'objective': model_meta.get('objective', objective),
            'metrics': model_meta['metrics'],
            'diagnostics': diagnostics,
            'train_params': model_meta.get('train_params', {}),
        }
        _append_experiment_log(experiment)

        return jsonify(
            {
                'message': 'Model trained successfully',
                'model_id': model_id,
                'metrics': primary_metrics,
                'all_metrics': model_meta['metrics'],
                'target_column': model_meta['target_column'],
                'feature_columns': model_meta['feature_columns'],
                'feature_schema': model_meta['feature_schema'],
                'problem_type': model_meta['problem_type'],
                'algorithm': model_meta['algorithm'],
                'objective': model_meta.get('objective', objective),
                'train_params': model_meta.get('train_params', {}),
                'diagnostics': diagnostics,
                'dataset_hash': _dataset_hash,
                'recommended_algorithm': recommendation['recommended_algorithm'],
                'algorithms': recommendation['algorithms'],
            }
        )
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/diagnostics', methods=['GET'])
def diagnostics():
    model_id = request.args.get('model_id')
    threshold = request.args.get('threshold')

    if model_id:
        if not _load_model(str(model_id)):
            return jsonify({'error': 'Model not found'}), 404
    elif not _current_model_ready():
        return jsonify({'error': 'Model not trained'}), 400

    diagnostics_payload = ((_active_model_meta or {}).get('diagnostics') or {})
    response = {
        'model_id': _active_model_id,
        'algorithm': (_active_model_meta or {}).get('algorithm'),
        'problem_type': (_active_model_meta or {}).get('problem_type'),
        'diagnostics': diagnostics_payload,
    }

    if threshold and diagnostics_payload.get('kind') == 'classification':
        try:
            thr = float(threshold)
            rows = diagnostics_payload.get('threshold_metrics') or []
            if rows:
                best = min(rows, key=lambda r: abs(float(r.get('threshold', 0.5)) - thr))
                response['selected_threshold_metrics'] = best
        except Exception:
            pass

    return jsonify(response)


@app.route('/explain', methods=['POST'])
def explain():
    if not _current_model_ready():
        return jsonify({'error': 'Model not trained'}), 400

    data = request.json or {}
    model_id = data.get('model_id')
    sample_input = data.get('input')

    if model_id:
        if not _load_model(str(model_id)):
            return jsonify({'error': 'Model not found'}), 404

    feature_schema = (_active_model_meta or {}).get('feature_schema', {})
    if not feature_schema:
        return jsonify({'error': 'Feature schema unavailable for active model'}), 500

    try:
        return jsonify(explain_model(_active_model, feature_schema, sample_input))
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/explain/compare', methods=['POST'])
def explain_compare():
    if not _current_model_ready():
        return jsonify({'error': 'Model not trained'}), 400

    data = request.json or {}
    model_a = str(data.get('model_a_id') or '')
    model_b = str(data.get('model_b_id') or '')
    sample_input = data.get('input')

    if not model_a or not model_b:
        return jsonify({'error': 'model_a_id and model_b_id are required'}), 400

    prev_model_id = _active_model_id

    def _run_for(model_id: str) -> Optional[Dict[str, Any]]:
        if not _load_model(model_id):
            return None
        schema = (_active_model_meta or {}).get('feature_schema', {})
        return {
            'model_id': model_id,
            'algorithm': (_active_model_meta or {}).get('algorithm'),
            'explain': explain_model(_active_model, schema, sample_input),
        }

    try:
        a = _run_for(model_a)
        b = _run_for(model_b)

        if a is None or b is None:
            return jsonify({'error': 'One or both model ids are invalid'}), 404

        a_features = {x['feature'] for x in a['explain'].get('global_feature_importance', [])[:10]}
        b_features = {x['feature'] for x in b['explain'].get('global_feature_importance', [])[:10]}

        overlap = sorted(a_features.intersection(b_features))

        return jsonify({'model_a': a, 'model_b': b, 'top_feature_overlap': overlap})
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if prev_model_id:
            _set_active_model(prev_model_id)


@app.route('/explain/whatif', methods=['POST'])
def explain_whatif():
    if not _current_model_ready():
        return jsonify({'error': 'Model not trained'}), 400

    data = request.json or {}
    model_id = data.get('model_id')
    base_input = data.get('base_input') or {}
    changes = data.get('changes') or {}

    if model_id:
        if not _load_model(str(model_id)):
            return jsonify({'error': 'Model not found'}), 404

    if not isinstance(base_input, dict) or not isinstance(changes, dict):
        return jsonify({'error': 'base_input and changes must be JSON objects'}), 400

    feature_schema = (_active_model_meta or {}).get('feature_schema', {})
    candidate = dict(base_input)
    candidate.update(changes)

    try:
        baseline_pred, _ = make_prediction(_active_model, base_input, feature_schema)
        changed_pred, _ = make_prediction(_active_model, candidate, feature_schema)

        baseline_explain = explain_model(_active_model, feature_schema, base_input)
        changed_explain = explain_model(_active_model, feature_schema, candidate)

        base_contrib = {
            row['feature']: float(row['contribution'])
            for row in baseline_explain.get('local_contributions', [])
        }
        changed_contrib = {
            row['feature']: float(row['contribution'])
            for row in changed_explain.get('local_contributions', [])
        }

        deltas = []
        for feat in set(base_contrib.keys()).union(changed_contrib.keys()):
            deltas.append(
                {
                    'feature': feat,
                    'delta': float(changed_contrib.get(feat, 0.0) - base_contrib.get(feat, 0.0)),
                }
            )
        deltas.sort(key=lambda x: abs(x['delta']), reverse=True)

        return jsonify(
            {
                'baseline_prediction': baseline_pred,
                'changed_prediction': changed_pred,
                'prediction_delta': float(changed_pred) - float(baseline_pred)
                if isinstance(changed_pred, (int, float)) and isinstance(baseline_pred, (int, float))
                else None,
                'top_contribution_shifts': deltas[:10],
            }
        )
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/predict', methods=['POST'])
def predict():
    data = request.json or {}

    model_id = data.pop('model_id', None)
    if model_id:
        if not _load_model(str(model_id)):
            return jsonify({'error': 'Model not found'}), 404
    elif not _current_model_ready():
        return jsonify({'error': 'Model not trained'}), 400

    feature_schema = (_active_model_meta or {}).get('feature_schema', {})
    if not feature_schema:
        return jsonify({'error': 'Model feature schema not available'}), 500

    try:
        prediction, validation = make_prediction(_active_model, data, feature_schema)
        return jsonify(
            {
                'prediction': prediction,
                'model_id': _active_model_id,
                'validation': validation,
            }
        )
    except Exception as e:
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    _ensure_storage()
    _load_active_from_pointer()
    app.run(debug=True)
