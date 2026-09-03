"""Download and verify the public-domain source dataset."""

from hashlib import sha256
from pathlib import Path
from tempfile import NamedTemporaryFile
from urllib.request import urlopen
from zipfile import ZipFile

URL = "https://www.misata.studio/datasets/saas-subscription-analytics.zip"
EXPECTED_SHA256 = "732ed9bc732e94c379ee5c6ec73b7f7a69f216c646da5974fd407352c5c96c9c"
ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "data" / "raw"
REQUIRED = {"accounts.csv", "users.csv", "subscriptions.csv", "invoices.csv", "support_tickets.csv"}


def main() -> None:
    DESTINATION.mkdir(parents=True, exist_ok=True)
    with urlopen(URL) as response, NamedTemporaryFile(suffix=".zip") as temporary:
        payload = response.read()
        digest = sha256(payload).hexdigest()
        if digest != EXPECTED_SHA256:
            raise RuntimeError(f"Checksum mismatch: expected {EXPECTED_SHA256}, got {digest}")
        temporary.write(payload)
        temporary.flush()
        with ZipFile(temporary.name) as archive:
            names = {Path(name).name for name in archive.namelist()}
            missing = REQUIRED - names
            if missing:
                raise RuntimeError(f"Archive is missing: {', '.join(sorted(missing))}")
            archive.extractall(DESTINATION)
    print(f"Downloaded and verified {len(REQUIRED)} tables in {DESTINATION}")


if __name__ == "__main__":
    main()

