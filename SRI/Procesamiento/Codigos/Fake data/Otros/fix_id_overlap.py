"""
Fix fake-data ID overlap so that:
  - Within each year, ≥ 50% of CEDULA_PK match between F107 and F102
  - Across years, ≥ 70% of all unique IDs appear in more than one year

Strategy
--------
1. Generate a global pool of 13 000 synthetic IDs.
2. For each year, draw ~10 000 IDs for F107 and ~9 500 for F102 from the same
   pool, forcing at least 55% overlap within the year.
3. Because the pool is only 13 000 and each year draws ~10 000, pairwise
   across-year overlap is guaranteed ≥ 70% by the pigeonhole principle.
4. Replace the CEDULA_PK column in every .dta file with the new IDs,
   preserving all other data and row structure.
"""

import os
import string
import numpy as np
import pandas as pd

# ── Configuration ──────────────────────────────────────────────────────────
BASE = (
    "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/"
    "Mi unidad/Trabajos/Observatorio de Políticas Públicas/"
    "Observatorio GH/SRI/Procesamiento/Bases/Fake"
)
F107_DIR = os.path.join(BASE, "F107")
F102_DIR = os.path.join(BASE, "F102")

POOL_SIZE = 15_000          # total distinct IDs available
ID_LEN = 10                 # character length of each synthetic ID
MIN_WITHIN_YEAR_PCT = 0.55  # target within-year shared fraction (> 50%)
SEED = 42

# ── 1. Generate the global ID pool ────────────────────────────────────────
rng = np.random.default_rng(SEED)
chars = list(string.ascii_uppercase + string.digits)

pool: list[str] = []
seen: set[str] = set()
while len(pool) < POOL_SIZE:
    new_id = "".join(rng.choice(chars, size=ID_LEN))
    if new_id not in seen:
        seen.add(new_id)
        pool.append(new_id)

print(f"Global ID pool: {len(pool)} unique IDs of length {ID_LEN}")

# ── 2. Discover available years ───────────────────────────────────────────
def extract_year(fname: str, prefix: str) -> str:
    return fname.replace(f"{prefix}_", "").replace(".dta", "")

f107_years = sorted(
    extract_year(f, "F107")
    for f in os.listdir(F107_DIR)
    if f.endswith(".dta")
)
f102_years = sorted(
    extract_year(f, "F102")
    for f in os.listdir(F102_DIR)
    if f.endswith(".dta")
)
all_years = sorted(set(f107_years) | set(f102_years))

print(f"F107 years: {f107_years}")
print(f"F102 years: {f102_years}")

# ── 3. Read current ID counts per file ────────────────────────────────────
id_counts: dict[str, dict[str, int]] = {}
for yr in all_years:
    counts: dict[str, int] = {}
    if yr in f107_years:
        df = pd.read_stata(
            os.path.join(F107_DIR, f"F107_{yr}.dta"),
            columns=["CEDULA_PK_empleado"],
        )
        # exclude empty-string IDs
        counts["f107_unique"] = df.loc[
            df["CEDULA_PK_empleado"] != "", "CEDULA_PK_empleado"
        ].nunique()
        counts["f107_rows"] = len(df)
    if yr in f102_years:
        df = pd.read_stata(
            os.path.join(F102_DIR, f"F102_{yr}.dta"),
            columns=["CEDULA_PK"],
        )
        counts["f102_unique"] = df.loc[
            df["CEDULA_PK"] != "", "CEDULA_PK"
        ].nunique()
        counts["f102_rows"] = len(df)
    id_counts[yr] = counts

# ── 4. Assign new IDs per year ────────────────────────────────────────────
pool_arr = np.array(pool)

# Store the mapping {year: {"f107": {old_id: new_id}, "f102": {old_id: new_id}}}
year_mappings: dict[str, dict] = {}

for yr in all_years:
    c = id_counts[yr]
    n107 = c.get("f107_unique", 0)
    n102 = c.get("f102_unique", 0)

    # How many IDs are shared between F107 and F102
    n_shared = int(MIN_WITHIN_YEAR_PCT * max(n107, n102))
    n_shared = min(n_shared, n107, n102)  # can't share more than available

    n_f107_only = n107 - n_shared
    n_f102_only = n102 - n_shared

    total_needed = n_shared + n_f107_only + n_f102_only
    if total_needed > POOL_SIZE:
        raise ValueError(
            f"Year {yr}: need {total_needed} IDs but pool has only {POOL_SIZE}"
        )

    # Draw from the pool (random permutation → slice)
    perm = rng.permutation(POOL_SIZE)
    shared_new = pool_arr[perm[:n_shared]].tolist()
    f107_only_new = pool_arr[perm[n_shared : n_shared + n_f107_only]].tolist()
    f102_only_new = pool_arr[
        perm[n_shared + n_f107_only : n_shared + n_f107_only + n_f102_only]
    ].tolist()

    f107_new = shared_new + f107_only_new
    f102_new = shared_new + f102_only_new

    # Shuffle so the ordering isn't obviously structured
    rng.shuffle(f107_new)
    rng.shuffle(f102_new)

    year_mappings[yr] = {"f107_new": f107_new, "f102_new": f102_new}

    overlap_pct_107 = n_shared / n107 * 100 if n107 else 0
    overlap_pct_102 = n_shared / n102 * 100 if n102 else 0
    print(
        f"  {yr}: shared={n_shared}  "
        f"F107={n107}({overlap_pct_107:.0f}%)  "
        f"F102={n102}({overlap_pct_102:.0f}%)"
    )


# ── 5. Build old→new mappings and rewrite .dta files ─────────────────────
def fix_numeric_formats(df: pd.DataFrame) -> None:
    """Workaround: some fake .dta files have %s formats on numeric cols."""
    # This is handled by pandas on read, so nothing to do here
    pass


def build_mapping(
    df: pd.DataFrame, id_col: str, new_ids: list[str]
) -> dict[str, str]:
    """Map each unique non-empty old ID to a new ID (1-to-1)."""
    old_unique = sorted(df.loc[df[id_col] != "", id_col].unique())
    if len(old_unique) > len(new_ids):
        raise ValueError(
            f"Need {len(old_unique)} IDs but only have {len(new_ids)}"
        )
    return dict(zip(old_unique, new_ids[: len(old_unique)]))


print("\n── Rewriting F107 files ──")
for yr in f107_years:
    path = os.path.join(F107_DIR, f"F107_{yr}.dta")
    df = pd.read_stata(path)
    mapping = build_mapping(df, "CEDULA_PK_empleado", year_mappings[yr]["f107_new"])
    df["CEDULA_PK_empleado"] = df["CEDULA_PK_empleado"].map(mapping).fillna("")
    # Also update RUC_PK_empleado if it mirrors CEDULA_PK_empleado
    if "RUC_PK_empleado" in df.columns:
        df["RUC_PK_empleado"] = df["CEDULA_PK_empleado"]
    df.to_stata(path, write_index=False, version=118)
    print(f"  F107_{yr}.dta  ✓  ({len(mapping)} IDs remapped)")

print("\n── Rewriting F102 files ──")
for yr in f102_years:
    path = os.path.join(F102_DIR, f"F102_{yr}.dta")
    df = pd.read_stata(path)
    mapping = build_mapping(df, "CEDULA_PK", year_mappings[yr]["f102_new"])
    df["CEDULA_PK"] = df["CEDULA_PK"].map(mapping).fillna("")
    # Also update RUC_PK if present (company ID for the person)
    if "RUC_PK" in df.columns:
        df["RUC_PK"] = df["CEDULA_PK"]
    df.to_stata(path, write_index=False, version=118)
    print(f"  F102_{yr}.dta  ✓  ({len(mapping)} IDs remapped)")


# ── 6. Verify results ────────────────────────────────────────────────────
print("\n── Verification ──")

all_ids_ever: set[str] = set()
year_id_sets: dict[str, set[str]] = {}

# Collect IDs per year (union of F107 and F102)
for yr in all_years:
    ids_yr: set[str] = set()
    if yr in f107_years:
        df = pd.read_stata(
            os.path.join(F107_DIR, f"F107_{yr}.dta"),
            columns=["CEDULA_PK_empleado"],
        )
        ids_yr |= set(df.loc[df["CEDULA_PK_empleado"] != "", "CEDULA_PK_empleado"])
    if yr in f102_years:
        df = pd.read_stata(
            os.path.join(F102_DIR, f"F102_{yr}.dta"),
            columns=["CEDULA_PK"],
        )
        ids_yr |= set(df.loc[df["CEDULA_PK"] != "", "CEDULA_PK"])
    year_id_sets[yr] = ids_yr
    all_ids_ever |= ids_yr

# Within-year overlap
print("\nWithin-year overlap (F107 ∩ F102):")
for yr in sorted(set(f107_years) & set(f102_years)):
    df107 = pd.read_stata(
        os.path.join(F107_DIR, f"F107_{yr}.dta"),
        columns=["CEDULA_PK_empleado"],
    )
    df102 = pd.read_stata(
        os.path.join(F102_DIR, f"F102_{yr}.dta"),
        columns=["CEDULA_PK"],
    )
    ids_107 = set(df107.loc[df107["CEDULA_PK_empleado"] != "", "CEDULA_PK_empleado"])
    ids_102 = set(df102.loc[df102["CEDULA_PK"] != "", "CEDULA_PK"])
    overlap = ids_107 & ids_102
    pct107 = len(overlap) / len(ids_107) * 100 if ids_107 else 0
    pct102 = len(overlap) / len(ids_102) * 100 if ids_102 else 0
    status = "✓" if pct107 >= 50 and pct102 >= 50 else "✗"
    print(
        f"  {yr}: overlap={len(overlap):,}  "
        f"F107={pct107:.1f}%  F102={pct102:.1f}%  {status}"
    )

# Across-year overlap
from collections import Counter

id_year_count = Counter()
for yr, ids in year_id_sets.items():
    for eid in ids:
        id_year_count[eid] += 1

multi_year = sum(1 for c in id_year_count.values() if c > 1)
total_unique = len(id_year_count)
pct_multi = multi_year / total_unique * 100 if total_unique else 0

print(f"\nAcross-year overlap:")
print(f"  Total unique IDs: {total_unique:,}")
print(f"  IDs in 2+ years:  {multi_year:,} ({pct_multi:.1f}%)")
status = "✓" if pct_multi >= 70 else "✗"
print(f"  Target ≥ 70%:     {status}")
