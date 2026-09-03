"""Auditable SaaS KPI calculations."""

import numpy as np
import pandas as pd


def build_account_mart(tables: dict[str, pd.DataFrame]) -> pd.DataFrame:
    accounts = tables["accounts"]
    subscriptions = tables["subscriptions"]
    tickets = tables["support_tickets"]
    users = tables["users"]
    invoices = tables["invoices"]

    ticket_summary = tickets.groupby("account_id").agg(
        ticket_count=("ticket_id", "size"),
        avg_resolution_hours=("resolution_hours", "mean"),
        avg_satisfaction=("satisfaction_score", "mean"),
        open_tickets=("resolved_at", lambda x: x.isna().sum()),
    )
    user_summary = users.groupby("account_id").size().rename("user_count")
    invoice_summary = invoices.groupby("account_id").agg(
        invoiced_amount=("amount", "sum"),
        invoice_count=("invoice_id", "size"),
        paid_invoices=("status", lambda x: x.eq("paid").sum()),
    )

    mart = accounts.merge(subscriptions, on="account_id", validate="one_to_one")
    mart = mart.join(ticket_summary, on="account_id").join(user_summary, on="account_id")
    mart = mart.join(invoice_summary, on="account_id")
    mart[["ticket_count", "open_tickets", "user_count", "invoice_count", "paid_invoices"]] = (
        mart[
            ["ticket_count", "open_tickets", "user_count", "invoice_count", "paid_invoices"]
        ].fillna(0)
    )
    mart["seat_utilization"] = mart["user_count"] / mart["seats"]
    mart["ticket_rate_per_100_users"] = np.where(
        mart["user_count"].gt(0), mart["ticket_count"] / mart["user_count"] * 100, np.nan
    )
    mart["invoice_collection_rate"] = mart["paid_invoices"] / mart["invoice_count"]
    mart["is_churned"] = mart["status"].eq("churned")
    mart["signup_cohort"] = mart["signup_date"].dt.to_period("Q").astype(str)
    return mart


def executive_kpis(mart: pd.DataFrame, invoices: pd.DataFrame) -> pd.Series:
    active = mart["status"].eq("active")
    paid_amount = invoices.loc[invoices["status"].eq("paid"), "amount"].sum()
    return pd.Series(
        {
            "accounts": len(mart),
            "active_accounts": int(active.sum()),
            "active_mrr": mart.loc[active, "mrr"].sum(),
            "active_arr_run_rate": mart.loc[active, "mrr"].sum() * 12,
            "active_arpa": mart.loc[active, "mrr"].mean(),
            "logo_churn_rate": mart["is_churned"].mean(),
            "median_seat_utilization": mart["seat_utilization"].median(),
            "invoice_collection_rate": invoices["status"].eq("paid").mean(),
            "cash_collected": paid_amount,
            "open_ticket_rate": mart["open_tickets"].sum() / mart["ticket_count"].sum(),
        },
        name="value",
    )


def segment_summary(mart: pd.DataFrame, by: str) -> pd.DataFrame:
    return (
        mart.groupby(by, observed=True)
        .agg(
            accounts=("account_id", "nunique"),
            active_mrr=("mrr", lambda x: x[mart.loc[x.index, "status"].eq("active")].sum()),
            churn_rate=("is_churned", "mean"),
            median_seat_utilization=("seat_utilization", "median"),
            tickets_per_account=("ticket_count", "mean"),
            avg_satisfaction=("avg_satisfaction", "mean"),
        )
        .sort_values("active_mrr", ascending=False)
        .reset_index()
    )

