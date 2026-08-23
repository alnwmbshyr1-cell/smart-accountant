from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass
class Coverage:
    file: str
    hit: int = 0
    total: int = 0

    @property
    def percent(self) -> float:
        return 100.0 * self.hit / self.total if self.total else 0.0


def parse_lcov(path: Path) -> list[Coverage]:
    records: list[Coverage] = []
    current: Coverage | None = None
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("SF:"):
            if current is not None:
                records.append(current)
            current = Coverage(line[3:])
        elif current is not None and line.startswith("LF:"):
            current.total += int(line[3:])
        elif current is not None and line.startswith("LH:"):
            current.hit += int(line[3:])
        elif line == "end_of_record" and current is not None:
            records.append(current)
            current = None
    if current is not None:
        records.append(current)
    return records


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1]
    records = parse_lcov(root / "coverage" / "lcov.info")
    for record in sorted(records, key=lambda item: item.percent):
        print(f"{record.percent:7.2f}% {record.hit:4d}/{record.total:<4d} {record.file}")
    hit = sum(record.hit for record in records)
    total = sum(record.total for record in records)
    print(f"TOTAL {100.0 * hit / total:.2f}% {hit}/{total}")
