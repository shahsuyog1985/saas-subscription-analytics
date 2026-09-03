"""Dataset loading and validation helpers."""

from pathlib import Path

import pandas as pd

TABLES = ("accounts", "users", "subscriptions", "invoices", "support_tickets")
DATE_COLUMNS = {
    "accounts": ["signup_date"],
    "subscriptions": ["started_on", "ended_on"],
    "invoices": ["invoice_date"],
    "support_tickets": ["opened_at", "resolved_at"],
}


def load_data(data_dir: Path) -> dict[str, pd.DataFrame]:
    """Load all source tables and parse documented date columns."""
    missing = [name for name in TABLES if not (data_dir / f"{name}.csv").exists()]
    if missing:
        raise FileNotFoundError(
            f"Missing tables: {', '.join(missing)}. Run `python scripts/download_data.py`."
        )
    return {
        name: pd.read_csv(data_dir / f"{name}.csv", parse_dates=DATE_COLUMNS.get(name))
        for name in TABLES
    }


def validate_data(tables: dict[str, pd.DataFrame]) -> None:
    """Raise AssertionError when core relational or business rules fail."""
    accounts = tables["accounts"]
    subscriptions = tables["subscriptions"]
    account_ids = set(accounts["account_id"])

    assert accounts["account_id"].notna().all()
    assert accounts["account_id"].is_unique
    assert subscriptions["subscription_id"].is_unique
    assert len(subscriptions) == len(accounts)
    assert subscriptions["account_id"].is_unique

    for name in ("users", "subscriptions", "invoices", "support_tickets"):
        assert set(tables[name]["account_id"]).issubset(account_ids), f"orphan key in {name}"

    joined = subscriptions.merge(
        accounts[["account_id", "employee_count"]], on="account_id", validate="one_to_one"
    )
    assert (joined["seats"] <= joined["employee_count"]).all()
    assert subscriptions.loc[subscriptions["status"].eq("active"), "ended_on"].isna().all()
    assert subscriptions.loc[subscriptions["status"].eq("churned"), "ended_on"].notna().all()

