from pathlib import Path

import pandas as pd
import pytest

from src.data import load_data, validate_data

DATA_DIR = Path(__file__).resolve().parents[1] / "data" / "raw"


@pytest.fixture(scope="module")
def tables():
    return load_data(DATA_DIR)


def test_expected_row_counts(tables):
    assert {name: len(frame) for name, frame in tables.items()} == {
        "accounts": 1200,
        "users": 21884,
        "subscriptions": 1200,
        "invoices": 14500,
        "support_tickets": 5600,
    }


def test_integrity_rules(tables):
    validate_data(tables)


def test_mrr_matches_plan_price(tables):
    expected_price = {"Starter": 12, "Growth": 24, "Business": 44, "Enterprise": 79}
    subscriptions = tables["subscriptions"].merge(
        tables["accounts"][["account_id", "plan"]], on="account_id", validate="one_to_one"
    )
    calculated = subscriptions["seats"] * subscriptions["plan"].map(expected_price)
    pd.testing.assert_series_equal(subscriptions["mrr"], calculated.astype(float), check_names=False)


def test_users_are_unique(tables):
    assert tables["users"]["user_id"].is_unique
    assert tables["users"]["email"].is_unique
