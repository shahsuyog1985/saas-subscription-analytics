.PHONY: data analyze test lint clean

data:
	python scripts/download_data.py

analyze:
	python -m src.analysis

test:
	python -m pytest

lint:
	python -m ruff check .

clean:
	python scripts/clean_outputs.py
