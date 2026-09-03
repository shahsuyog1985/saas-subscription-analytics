from pathlib import Path

from src.data import load_data
from src.metrics import build_account_mart, executive_kpis

DATA_DIR = Path(__file__).resolve().parents[1] / "data" / "raw"


def test_kpis_reconcile_to_source():
    tables = load_data(DATA_DIR)
    mart = build_account_mart(tables)
    kpis = executive_kpis(mart, tables["invoices"])
    assert kpis["accounts"] == 1200
    assert mart["status"].value_counts().to_dict() == {
        "active": 1030,
        "churned": 86,
        "trialing": 46,
        "past_due": 38,
    }
    assert kpis["active_arr_run_rate"] == kpis["active_mrr"] * 12
    assert 0 <= kpis["logo_churn_rate"] <= 1
    assert 0 <= kpis["invoice_collection_rate"] <= 1


def test_account_mart_has_one_row_per_account():
    tables = load_data(DATA_DIR)
    mart = build_account_mart(tables)
    assert len(mart) == len(tables["accounts"])
    assert mart["account_id"].is_unique
