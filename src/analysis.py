"""Run the full reproducible analysis and write presentation-ready artifacts."""

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

from src.data import load_data, validate_data
from src.metrics import build_account_mart, executive_kpis, segment_summary

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data" / "raw"
FIGURE_DIR = ROOT / "reports" / "figures"
TABLE_DIR = ROOT / "reports" / "tables"


def _style() -> None:
    sns.set_theme(style="whitegrid", context="talk")
    plt.rcParams.update({"figure.dpi": 120, "savefig.bbox": "tight", "axes.titleweight": "bold"})


def _save_plan_chart(plan: pd.DataFrame) -> None:
    fig, axes = plt.subplots(1, 2, figsize=(13, 5))
    sns.barplot(data=plan, x="plan", y="active_mrr", hue="plan", legend=False, ax=axes[0])
    axes[0].set(title="Active MRR by plan", xlabel="", ylabel="Active MRR ($)")
    axes[0].tick_params(axis="x", rotation=20)
    sns.barplot(data=plan, x="plan", y="churn_rate", hue="plan", legend=False, ax=axes[1])
    axes[1].set(title="Logo churn by plan", xlabel="", ylabel="Churn rate")
    axes[1].yaxis.set_major_formatter(lambda x, _: f"{x:.0%}")
    axes[1].tick_params(axis="x", rotation=20)
    fig.savefig(FIGURE_DIR / "plan_performance.png")
    plt.close(fig)


def _save_support_chart(mart: pd.DataFrame) -> None:
    buckets = pd.qcut(mart["ticket_rate_per_100_users"], 4, duplicates="drop")
    support = (
        mart.assign(support_load_quartile=buckets)
        .groupby("support_load_quartile", observed=True)
        .agg(churn_rate=("is_churned", "mean"), accounts=("account_id", "size"))
        .reset_index()
    )
    support["support_load_quartile"] = [f"Q{i + 1}" for i in range(len(support))]
    support.to_csv(TABLE_DIR / "support_load_and_churn.csv", index=False)
    fig, ax = plt.subplots(figsize=(8, 5))
    sns.barplot(data=support, x="support_load_quartile", y="churn_rate", ax=ax, color="#5B8FF9")
    ax.set(
        title="Support load is not a monotonic churn predictor",
        xlabel="Tickets per 100 users (quartile)",
        ylabel="Logo churn",
    )
    ax.yaxis.set_major_formatter(lambda x, _: f"{x:.0%}")
    fig.savefig(FIGURE_DIR / "support_load_churn.png")
    plt.close(fig)


def _save_cohort_chart(mart: pd.DataFrame) -> None:
    cohort = (
        mart.groupby("signup_cohort", observed=True)
        .agg(accounts=("account_id", "size"), retention_rate=("is_churned", lambda x: 1 - x.mean()))
        .reset_index()
    )
    cohort.to_csv(TABLE_DIR / "cohort_retention.csv", index=False)
    fig, ax = plt.subplots(figsize=(11, 5))
    sns.lineplot(data=cohort, x="signup_cohort", y="retention_rate", marker="o", ax=ax)
    ax.set(title="Snapshot logo retention by signup cohort", xlabel="Signup quarter", ylabel="Retention")
    ax.yaxis.set_major_formatter(lambda x, _: f"{x:.0%}")
    ax.tick_params(axis="x", rotation=45)
    fig.savefig(FIGURE_DIR / "cohort_retention.png")
    plt.close(fig)


def main() -> None:
    FIGURE_DIR.mkdir(parents=True, exist_ok=True)
    TABLE_DIR.mkdir(parents=True, exist_ok=True)
    tables = load_data(DATA_DIR)
    validate_data(tables)
    mart = build_account_mart(tables)
    kpis = executive_kpis(mart, tables["invoices"])
    plan = segment_summary(mart, "plan")
    industry = segment_summary(mart, "industry")

    kpis.to_csv(TABLE_DIR / "executive_kpis.csv", header=True)
    plan.to_csv(TABLE_DIR / "plan_summary.csv", index=False)
    industry.to_csv(TABLE_DIR / "industry_summary.csv", index=False)
    mart.to_csv(TABLE_DIR / "account_mart.csv", index=False)

    _style()
    _save_plan_chart(plan)
    _save_support_chart(mart)
    _save_cohort_chart(mart)
    print(kpis.to_string())


if __name__ == "__main__":
    main()
