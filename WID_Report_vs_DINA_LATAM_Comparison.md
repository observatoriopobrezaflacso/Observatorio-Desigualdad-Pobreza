# Comparison: WID Report vs. dina-latam Codebase — How Income Is Calculated for Ecuador

**Date: February 2026**

---

## Executive Summary

The WID.world report I produced (general methodology) describes the DINA framework at a **conceptual level**. The `dina-latam` codebase reveals the **exact operational implementation** for Ecuador. This comparison shows how the abstract concepts map to concrete code steps, and highlights important Ecuador-specific details that only become visible from the code.

---

## 1. Income Variable Definition: Report vs. Code

### What the Report Said

The benchmark income concept is **pre-tax national income**: labor + capital income after social insurance (pensions, unemployment) but before other redistribution.

### What the Code Actually Does

The code builds income from **7 base survey variables** extracted from CEPAL-harmonized ENEMDU data:

| Variable | CEPAL Source                    | Meaning                                     |
| -------- | ------------------------------- | ------------------------------------------- |
| `wag`  | `sys_pe` + `yoemp_pe`       | Wages + other employment income             |
| `pen`  | `yjub_pe`                     | Pensions                                    |
| `mix`  | `gan_pe`                      | Self-employment / mixed income              |
| `bus`  | `gan_pe` (if `categ5_p==1`) | Business income (employer subset of mix)    |
| `cap`  | `ycap_pe`                     | Capital income (dividends, interest, rents) |
| `oth`  | `yotr_pe`                     | Other transfers (non-pension)               |
| `imp`  | `yaim_he / adults_house`      | Imputed rents (household → per adult)      |

**Total survey income** for Ecuador:

```
tot = wag + pen + mix + cap + oth
```

> [!IMPORTANT]
> Imputed rents (`imp`) are NOT included in the base total. They are added separately later during the rescaling stage. This is a design choice — imputed rents and mixed income are rescaled jointly (as `mir = mix + imp`) to match the SNA "Mixed Income + Operating Surplus of Households" item.

### Key gap identified

- The report mentions **retained corporate earnings** and **production taxes** allocated to individuals. The code confirms these are added in **separate imputation steps** (05b and 05c), not from the survey.

---

## 2. Ecuador's Pre-tax / Post-tax Treatment

### What the Report Said

The report described this generically: surveys are reconciled with national accounts and tax data.

### What the Code Reveals — Ecuador's Specific Path

Ecuador is classified as a **post-tax survey country**. This is a critical implementation detail:

```stata
// In 01e-clean-survey-data.do
local pf "pos"                       // ← default: post-tax
if inlist("`c'", "BRA", "CRI") {
    local pf "pre"                   // ← only Brazil & Costa Rica are pre-tax
}
```

**Consequence**: All Ecuador survey variables are created with the prefix `pos_` (e.g., `pos_wag_svy`, `pos_tot_svy`). The pipeline then **converts them to pre-tax** in step 04b by dividing by `(1 - effective_tax_rate)`:

```stata
// In 04b-build-pretax-surveys.do (for countries other than BRA/CRI)
gen ind_pre_`var' = ind_pos_`var' / (1 - eff_tax_rate_ipol)
```

If a year-specific effective tax rate file is missing for Ecuador, the code uses the **country average** across all available years.

> [!WARNING]
> This means Ecuador's pre-tax income is an **imputation** — the survey captures post-tax income, and pre-tax is estimated by reversing the tax rate. This introduces uncertainty, especially for years without direct effective tax rate data.

---

## 3. Top Income Correction (BFM): Ecuador's Coverage

### What the Report Said

General description of Pareto interpolation and tax data correction at the top.

### What the Code Reveals

The code uses the **BFM (Blanchet, Flores, Morgan) correction** — `bfmcorr` command in Stata — to merge survey bottom/middle with tax-data top. For Ecuador, the available tax data is **very limited**:

```
input_data/admin_data/ECU/
├── gpinter_ECU_2008.xlsx
├── gpinter_ECU_2009.xlsx
├── gpinter_ECU_2010.xlsx
├── gpinter_ECU_2011.xlsx
├── eff-tax-rate/          (6 files)
└── gpinter_adults/
```

**Ecuador only has BFM-compatible tax tabulations for 2008–2011.** For other years, the code extrapolates the correction using theta coefficients estimated from available years (steps 03d and 03e: `prepare-theta-extrapolation.do` and `extrapolate-bfm-correction.do`).

The BFM algorithm:

1. Ranks both survey and tax distributions
2. Finds a **merging point** (a trust region in the distribution where both sources agree)
3. Replaces the survey's upper tail with tax-data-derived estimates
4. Reweights to preserve total population

---

## 4. Rescaling to National Accounts: The Exact Formulas

### What the Report Said

Survey totals are rescaled to match SNA national accounts totals.

### What the Code Does (05b-rescale-and-impute.do)

For Ecuador, each income component is rescaled **individually** with its own scaling factor:

```stata
// Each variable gets its own factor
gen ind_`var'_sca = ind_`var' * scaling_factor * _factor   // for adults ≥ 20
```

The scaling factors are computed in advance from a comparison of survey aggregates to UN SNA national accounts (step 05a). The SNA data comes from the **UNDATA-WID-Merged.dta** file, which pairs UN System of National Accounts data with WID macro data.

**Ecuador also has a special currency step** for pre-dollarization (before year 2000):

```stata
// Harmonize special case (ECU)
// Uses World Bank exchange rates to convert sucres → USD
replace TOT_B5g_wid = TOT_B5g_wid * xr_ecu_`z' if year == `z' & country == "ECU" & year < 2000
```

---

## 5. What Gets Added Beyond the Survey

After rescaling, the code adds three additional income components that come entirely from macro data / imputation:

### A. Undistributed Corporate Profits (05b)

```
uprofits_hh = (net retained earnings of private domestic corps.) × (share going to households)
```

These are imputed proportionally to **capital ownership proxies**:

- Proxy 1: Dividends & capital income (`ind_pre_cap`)
- Proxy 2: Employer income + dividends (if `categ5_p == 1`)
- Proxy 3: Employer income only
- Proxy 4: Capital income + imputed rents

The preferred proxy (nº2) combines business ownership with capital income.

### B. Taxes on Production (05c)

```
ind_tax_indg_pre = total_production_taxes × (individual's share of factor income)
```

Production/consumption taxes are allocated proportionally to each individual's share of total factor income.

### C. Leftover / Residual Income (05c)

Any remaining gap between the sum of all imputed components and total national income is allocated as:

- If gap is positive: `leftover = share_of_total_income × macro_gap_lcu`
- If gap is negative (exceeds NI): all components are scaled down proportionally

---

## 6. Final Income Aggregates: The Actual Formulas

Based on the code, the four income concepts for Ecuador are:

### Factor Income (`pre_fac`)

```
pre_fac_sca = pre_wag_sca + pre_mix_sca + pre_imp_sca + undistributed_profits
```

### Pre-tax National Income (`pre_tot_sca`)

```
pre_tot_sca = pre_wag_sca + pre_pen_sca + pre_cap_sca
            + pre_mix_sca + pre_imp_sca
            + undistributed_profits
            + production_taxes (imputed ∝ factor income)
            + leftover (residual to match NI)
```

### Post-tax Disposable Income (`pod_tot`)

```
pod_tot = pre_tot_sca − total_taxes + monetary_benefits
```

Where taxes include PIT, corporate tax, payroll, property, wealth, indirect taxes.

### Post-tax National Income (`pon_tot`)

```
pon_tot = pod_tot + in-kind_health + in-kind_education + other_in-kind
```

In-kind transfers sourced from **CEQ (Commitment to Equity)** incidence studies.

---

## 7.  Units of Observation

The code produces three versions for each income variable:

| Unit                 | Code Prefix | How Computed                                         |
| -------------------- | ----------- | ---------------------------------------------------- |
| Individual           | `ind_`    | Direct attribution to the income earner              |
| Equal-split narrow   | `esn_`    | Sum of couple's income ÷ 2 (married/partnered only) |
| Per-capita household | `pch_`    | Household total ÷ household size                    |

> [!NOTE]
> The config file (`_config.do`) shows Ecuador uses `"ind" "esn" "pch"` — note that "equal-split broad" (`esb`, dividing among all adults in household) is computed in the code but NOT included in the final output configuration. The WID "equal-split adults" (code `j`) maps to the **narrow** (`esn`) variant in this codebase, where income is split within couples only.

---

## 8. Critical Differences Between Report and Code

| Aspect                          | WID Report (Conceptual)                         | dina-latam Code (Operational)                                                                                            |
| ------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| **Survey tax status**     | Not specified per country                       | Ecuador is**post-tax** → requires pre-tax inversion                                                               |
| **Tax data availability** | "Tabulated income tax data from SRI"            | Only**4 years** of gpinter files (2008–2011); rest extrapolated                                                   |
| **Imputed rents**         | Included in income                              | Not in base total; rescaled separately as part of `mir`                                                                |
| **Informal sector**       | "Not explicitly modeled"                        | Confirmed: no explicit informal adjustment. It's captured only indirectly via SNA scaling                                |
| **Equal-split**           | "Equal-split adults" (vague)                    | Specifically =`esn`: income split within **couples** only, not among all household adults                        |
| **Currency**              | "Local currency" (USD post-2000)                | Explicit sucre→USD conversion for pre-2000 using WB exchange rates                                                      |
| **Top income method**     | "Generalized Pareto interpolation"              | Specifically**BFM correction** (`bfmcorr`): merging survey + tax by finding trust region, not just interpolation |
| **Undistributed profits** | "Allocated proportionally to capital income"    | 4 different proxies tested; proxy 2 (employer inc. + dividends) appears preferred                                        |
| **Data origin**           | "ENEMDU from INEC"                              | CEPAL-harmonized version of ENEMDU (pre-processed by ECLAC), NOT raw INEC data                                           |
| **Country adjustments**   | Suggested Ecuador may have specific adjustments | No Ecuador-specific adjustment in `01f` (only ARG, BRA, CRI have adjustments)                                          |

---

## 9. Ecuador-Specific Issues Found in the Code

1. **Ecuador is NOT flagged as an "exception country"** in the rescaling (05b line 520: `inlist("`c'", "BOL")`). This means Ecuador uses the standard variable list for rescaling, where Operating Surplus and Mixed Income are scaled separately — consistent with the 2024 DINA Update noting the split since 2018.
2. **Limited tax data**: With only 2008–2011 gpinter files, the top income correction for most years relies on **extrapolated theta coefficients**, making the top shares less certain for early and recent years.
3. **No social contributions subtracted**: Unlike Brazil (where social security contributions are explicitly subtracted from wages in 04b Section III), Ecuador has no such adjustment. The CEPAL survey's `yjub_pe` is taken as-is for pensions.
4. **Extreme value removal**: Individuals with income > 1000× the average are dropped (threshold is 500× for Argentina). This is a hard filter applied before any correction.
5. **Annualization**: c
